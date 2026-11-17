//
//  ContentViewModel.swift
//  FinixTapToPaySDKDemo
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation
import SwiftUI
import Combine
import FinixTapToPaySDK

// Avoid ambiguity between SwiftUI.Environment and FinixTapToPaySDK.TapToPayConfiguration.Environment
typealias TapToPayEnvironment = TapToPayConfiguration.Environment

class ContentViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var statusText: String = "Not Ready"
    @Published var amountText: String = "54.13"
    @Published var logOutput: String = "No activity yet"
    @Published var currentTransactionStatus: TransactionStatus? = nil
    @Published var selectedTransactionType: TransactionType? = nil
    @Published var showingAlert: Bool = false
    @Published var alertObject: AlertObject = AlertObject(title: "", message: "")
    @Published var showConfigurationSheet: Bool = false

    @Published var selectedEnvironment: TapToPayEnvironment = .sandbox

    /// Persisted on change, with the numeric fields clamped. A language change is also pushed to
    /// the live SDK instance.
    @Published var chargeOptions: ChargeOptions = ChargeOptionsStore.load() {
        didSet {
            let clamped = chargeOptions.sanitized()
            if clamped != chargeOptions { chargeOptions = clamped }
            guard chargeOptions != oldValue else { return }
            ChargeOptionsStore.save(chargeOptions)
            if chargeOptions.languageIdentifier != oldValue.languageIdentifier {
                finixTapToPay?.setUserInterfaceLanguage(chargeOptions.language)
                addLog("Tap to Pay UI language: \(chargeOptions.languageIdentifier ?? "system default")")
            }
        }
    }

    /// Drives the tip / surcharge sheet.
    @Published var pendingCharge: PendingCharge?
    /// Drives the signature capture sheet.
    @Published var signatureRequest: SignatureRequest?
    @Published var lastSummary: TransactionSummary?
    /// Reader configuration progress (0-100) reported by `configurationProgress` while preparing.
    @Published var prepareProgress: Int?
    /// Latest `transactionEvents` step, shown next to the transaction spinner.
    @Published var transactionProgressText: String?

    var isReaderReady: Bool {
        return statusText.lowercased().contains("ready")
    }

    // MARK: - Private Properties

    private var finixTapToPay: FinixTapToPay?
    var currentConfiguration: TapToPayConfiguration? // Made accessible for ConfigurationView
    private var cancellables = Set<AnyCancellable>()
    /// Set when the pre-charge sheet is confirmed; the charge starts once the sheet has
    /// finished dismissing so Apple's tap sheet is not presented over a closing sheet.
    private var queuedCharge: QueuedCharge?

    // MARK: - Initialization

    init() {
        setupInitialConfiguration()
    }

    // MARK: - Setup

    private func setupInitialConfiguration() {
        // No credentials ship in source control. Restore the configuration saved on this
        // device for the last-selected environment; with nothing saved the app starts
        // unconfigured — enter values via the Configuration sheet.
        guard let saved = SavedConfigurationStore.loadForLastSelectedEnvironment() else {
            markUnconfigured()
            return
        }

        updateConfiguration(saved)
    }

    private func markUnconfigured() {
        statusText = "Not Configured"
        addLog("Enter your Finix credentials and device ID via Configuration to begin")
    }

    func updateConfiguration(_ configuration: TapToPayConfiguration) {
        currentConfiguration = configuration
        selectedEnvironment = configuration.environment

        guard !configuration.credentials.username.isEmpty, !configuration.deviceId.isEmpty else {
            markUnconfigured()
            return
        }

        if !SavedConfigurationStore.save(configuration) {
            addLog("⚠️ Could not save the configuration — it applies to this session only")
        }
        finixTapToPay = makeSDK(configuration)

        addLog("Configuration updated for environment: \(configuration.environment.stringValue)")
        addLog("Merchant: \(configuration.merchant.merchantId)")
        addLog("Device: \(configuration.deviceId)")

        // Check link status
        Task {
            await checkLinkStatus()
        }
    }

    // MARK: - Actions

    func onLinkAccountTapped() {
        addLog("=== Link Account ===")

        guard let sdk = finixTapToPay else {
            statusText = "SDK not initialized"
            addLog("ERROR: SDK not initialized")
            return
        }

        statusText = "Linking..."

        Task {
            do {
                try await sdk.linkAccount()
                await MainActor.run {
                    statusText = "Account Linked - Ready to Prepare"
                    addLog("✅ Account linked successfully")
                }
            } catch {
                let errorString = error.localizedDescription
                let nsError = error as NSError

                // ProximityReader.PaymentCardReaderError code 20 = accountAlreadyLinked
                if nsError.domain == "ProximityReader.PaymentCardReaderError" && nsError.code == 20 {
                    await MainActor.run {
                        statusText = "Account Already Linked - Ready to Prepare"
                        addLog("ℹ️ Account already linked")
                    }
                } else {
                    await MainActor.run {
                        statusText = "Link Failed"
                        addLog("❌ Link failed: \(errorString)")
                    }
                }
            }
        }
    }

    func onPrepareTapped() {
        addLog("=== Prepare Reader ===")

        guard let sdk = finixTapToPay else {
            statusText = "SDK not initialized"
            addLog("ERROR: SDK not initialized")
            return
        }

        statusText = "Preparing..."
        prepareProgress = nil

        Task {
            do {
                try await sdk.prepareReader()
                await MainActor.run {
                    prepareProgress = nil
                    statusText = "Tap to Pay on iPhone is READY"
                    addLog("✅ Reader prepared successfully")
                }
            } catch {
                await MainActor.run {
                    prepareProgress = nil
                    statusText = "Prepare Failed"
                    addLog("❌ Prepare failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func onClearCachesTapped() {
        addLog("=== Clear Caches ===")

        guard let sdk = finixTapToPay else {
            addLog("ERROR: SDK not initialized")
            return
        }

        sdk.clearAllCaches()
        statusText = "Caches Cleared - Checking Status..."
        addLog("✅ All caches cleared")

        // Re-initialize
        if let config = currentConfiguration {
            finixTapToPay = makeSDK(config)
        }

        Task {
            await checkLinkStatus()
        }
    }

    func onSaleTapped() {
        selectedTransactionType = .sale
    }

    func onAuthTapped() {
        selectedTransactionType = .authorization
    }

    func onRefundTapped() {
        selectedTransactionType = .refund
    }

    func onTapToPayTapped() {
        guard let transactionType = selectedTransactionType else {
            showAlert(title: "Select Transaction Type", message: "Please select Sale, Auth, or Refund first")
            return
        }
        guard finixTapToPay != nil else {
            showAlert(title: "Error", message: "SDK not initialized")
            return
        }
        guard let baseCents = ChargeCalculator.amountInCents(from: amountText) else {
            showAlert(title: "Invalid Amount", message: "Please enter a valid amount")
            return
        }

        // Refunds skip tip and surcharge: the tap sheet would fold a tip into the refund amount.
        if transactionType != .refund && chargeOptions.needsPreChargeStep {
            pendingCharge = PendingCharge(type: transactionType, baseCents: baseCents)
        } else {
            startTransaction(type: transactionType, baseCents: baseCents, tipCents: nil)
        }
    }

    /// Called by the pre-charge sheet. `tipCents` is nil for "No Tip" or when tipping is off.
    func onPreChargeConfirmed(_ charge: PendingCharge, tipCents: Int?) {
        queuedCharge = QueuedCharge(type: charge.type, baseCents: charge.baseCents, tipCents: tipCents)
        pendingCharge = nil
    }

    func onPreChargeDismissed() {
        guard let queued = queuedCharge else { return }
        queuedCharge = nil
        startTransaction(type: queued.type, baseCents: queued.baseCents, tipCents: queued.tipCents)
    }

    func onSignatureCaptured(_ png: Data?) {
        signatureRequest = nil
        lastSummary?.signaturePNG = png
        addLog(png == nil ? "Signature skipped (blank)" : "Signature captured (kept locally, not uploaded)")
    }

    /// Cancels through the SDK. The pending `startTransaction` then throws
    /// `.transactionCancelled`, which is what moves the UI out of the processing state.
    func onCancelTapped() {
        guard let sdk = finixTapToPay else { return }
        addLog("Cancelling via sdk.cancelTransaction()")

        Task {
            do {
                try await sdk.cancelTransaction()
            } catch {
                await MainActor.run {
                    addLog("❌ cancelTransaction failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func onTransactionFinished() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Wait for 2 seconds then reset to show transaction buttons again
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                currentTransactionStatus = nil
                selectedTransactionType = nil
            }
        }
    }

    func onClearLogsTapped() {
        logOutput = "No activity yet"
    }

    // MARK: - Private Methods

    private func checkLinkStatus() async {
        guard let sdk = finixTapToPay else { return }

        let isLinked = await sdk.isAccountLinked()
        await MainActor.run {
            if isLinked {
                statusText = "Account Linked - Ready to Prepare"
                addLog("ℹ️ Account is linked")
            } else {
                statusText = "Account Not Linked"
                addLog("⚠️ Account not linked - use menu to link")
            }
        }
    }

    /// Creates the SDK instance and wires up its Combine publishers. Every place that
    /// (re)creates the instance goes through here so the subscriptions never go stale.
    private func makeSDK(_ configuration: TapToPayConfiguration) -> FinixTapToPay {
        let sdk = FinixTapToPay(configuration: configuration)

        cancellables.removeAll()
        sdk.transactionEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleTransactionEvent(event)
            }
            .store(in: &cancellables)
        sdk.configurationProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.prepareProgress = progress
            }
            .store(in: &cancellables)

        sdk.setUserInterfaceLanguage(chargeOptions.language)
        return sdk
    }

    private func handleTransactionEvent(_ event: TapToPayTransactionEvent) {
        switch event {
        case .preparingTransaction:
            transactionProgressText = "Preparing…"
            addLog("Event: preparingTransaction")
        case .readingCard:
            transactionProgressText = "Reading card…"
            addLog("Event: readingCard")
        case .cardRead:
            transactionProgressText = "Card read"
            addLog("Event: cardRead")
        case .processing:
            transactionProgressText = "Processing…"
            addLog("Event: processing")
        case .success:
            // Result details are logged where startTransaction returns.
            transactionProgressText = nil
            addLog("Event: success")
        case .failure(let error):
            transactionProgressText = nil
            addLog("Event: failure (\(error.code))")
        @unknown default:
            addLog("Event: unknown")
        }
    }

    private func startTransaction(type: TransactionType, baseCents: Int, tipCents: Int?) {
        guard let sdk = finixTapToPay else {
            showAlert(title: "Error", message: "SDK not initialized")
            return
        }

        // The SDK does not validate amounts, so keep tip and surcharge non-negative here.
        let tipCents = tipCents.flatMap { $0 > 0 ? $0 : nil }
        let surchargeCents = type == .refund
            ? nil
            : ChargeCalculator.surchargeCents(baseCents: baseCents, basisPoints: chargeOptions.surchargeBasisPoints)

        // Decided once, before the charge; the capture sheet and the summary use the same value.
        // The demo does not upload the signature, so it must not send `promptForSignature`:
        // that flag tells Finix an upload will follow.
        let breakdown = ChargeBreakdown(
            baseCents: baseCents,
            tipCents: tipCents,
            surchargeCents: surchargeCents,
            collectSignature: ChargeCalculator.requiresSignature(
                totalCents: baseCents + (tipCents ?? 0),
                rule: chargeOptions.signatureRule,
                thresholdCents: chargeOptions.signatureThresholdCents,
                isRefund: type == .refund
            )
        )

        addLog("=== Start Transaction ===")
        addLog("Type: \(type.displayName)")
        addLog("Base: \(ChargeCalculator.formatCurrency(cents: baseCents)) (\(baseCents) cents)")
        addLog("Tip: \(tipCents.map(String.init) ?? "none") | Surcharge: \(surchargeCents.map(String.init) ?? "none") | Signature (local only): \(breakdown.collectSignature)")

        lastSummary = nil
        currentTransactionStatus = .processing

        Task {
            do {
                let result = try await sdk.startTransaction(
                    amount: baseCents,
                    currency: "USD",
                    type: type,
                    surchargeAmount: surchargeCents,
                    tipAmount: tipCents
                )

                await MainActor.run {
                    currentTransactionStatus = .success
                    logTransactionResult(result)
                    lastSummary = TransactionSummary(type: type, breakdown: breakdown, result: result)
                    if breakdown.collectSignature {
                        presentSignatureRequest(SignatureRequest(
                            totalCents: result.amount,
                            cardBrand: result.cardBrand,
                            last4: result.last4
                        ))
                    }
                    onTransactionFinished()
                }
            } catch let error as TapToPayError where error.code == .transactionCancelled {
                await MainActor.run {
                    currentTransactionStatus = .failed
                    addLog("❌ Transaction cancelled")
                    onTransactionFinished()
                }
            } catch {
                await MainActor.run {
                    currentTransactionStatus = .failed
                    addLog("❌ Transaction failed: \(error.localizedDescription)")
                    onTransactionFinished()
                }
            }
        }
    }

    private func logTransactionResult(_ result: TapToPayTransactionResult) {
        addLog("✅ Transaction Successful")
        addLog("Amount: \(result.amount) \(result.currency)")
        addLog("Card: \(result.cardBrand ?? "Unknown") *\(result.last4 ?? "****")")
        addLog("Type: \(result.cardType ?? "Unknown")")
        addLog("Transaction ID: \(result.transactionIdentifier ?? "N/A")")
        addLog("Transfer ID: \(result.transferId ?? "N/A")")
        addLog("Transfer State: \(result.transferState ?? "N/A")")
        addLog("Trace ID: \(result.traceId ?? "N/A")")
        addLog("Time: \(result.timestamp)")
    }

    /// `startTransaction` returns while Apple's tap sheet is still animating away, and a sheet
    /// presented over it is dropped or garbled. The system sheet has no dismissal callback, so
    /// wait out the animation. The 0.8 s value is an estimate; confirm it on a device.
    private func presentSignatureRequest(_ request: SignatureRequest) {
        Task {
            try? await Task.sleep(nanoseconds: Self.tapSheetDismissDelay)
            await MainActor.run {
                signatureRequest = request
            }
        }
    }

    private static let tapSheetDismissDelay: UInt64 = 800_000_000

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"

        DispatchQueue.main.async {
            if self.logOutput == "No activity yet" {
                self.logOutput = logEntry
            } else {
                self.logOutput += "\n" + logEntry
            }
        }
    }

    private func showAlert(title: String, message: String) {
        alertObject = AlertObject(title: title, message: message)
        showingAlert = true
    }
}

// MARK: - Supporting Types

enum TransactionStatus {
    case processing
    case success
    case failed
}

struct AlertObject {
    let title: String
    let message: String
}

struct PendingCharge: Identifiable {
    let id = UUID()
    let type: TransactionType
    let baseCents: Int
}

private struct QueuedCharge {
    let type: TransactionType
    let baseCents: Int
    let tipCents: Int?
}

struct SignatureRequest: Identifiable {
    let id = UUID()
    let totalCents: Int
    let cardBrand: String?
    let last4: String?
}

/// The demo keeps its own record of the charge: `TapToPayTransactionResult` has no tip,
/// surcharge or signature fields (and `cardType` is always nil).
struct TransactionSummary {
    let type: TransactionType
    let breakdown: ChargeBreakdown
    /// `result.amount`: base + tip, never the surcharge.
    let totalCents: Int
    let transferId: String?
    let traceId: String?
    let cardBrand: String?
    let last4: String?
    var signaturePNG: Data?

    /// The id shown on the main screen: the Finix transfer, else the trace id.
    var displayId: String {
        transferId ?? traceId ?? "N/A"
    }

    init(type: TransactionType, breakdown: ChargeBreakdown, result: TapToPayTransactionResult) {
        self.type = type
        self.breakdown = breakdown
        self.totalCents = result.amount
        self.transferId = result.transferId
        self.traceId = result.traceId
        self.cardBrand = result.cardBrand
        self.last4 = result.last4
    }
}

extension TapToPayEnvironment {
    var stringValue: String {
        switch self {
        case .production:
            return "Production"
        case .sandbox:
            return "Sandbox"
        @unknown default:
            return "Unknown"
        }
    }
}
