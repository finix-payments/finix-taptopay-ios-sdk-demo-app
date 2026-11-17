//
//  ChargeOptions.swift
//  FinixTapToPaySDKDemo
//

import Foundation

enum SignatureRule: String, Codable, CaseIterable, Identifiable {
    case always
    case never
    case threshold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .never: return "Never"
        case .threshold: return "On threshold"
        }
    }
}

/// Demo-local stand-in for the tip / surcharge / signature settings the Checkout app reads
/// from the Finix device record. Everything defaults to off, so an untouched demo behaves
/// like a plain sale.
struct ChargeOptions: Codable, Equatable {
    var tipEnabled: Bool = false
    /// 300 = 3.00%
    var surchargeBasisPoints: Int = 0
    var signatureRule: SignatureRule = .never
    var signatureThresholdCents: Int = 0
    /// BCP 47 identifier passed to `setUserInterfaceLanguage`; nil follows the system language.
    var languageIdentifier: String? = nil

    var language: Locale.Language? {
        languageIdentifier.map { Locale.Language(identifier: $0) }
    }

    /// Whether the pre-charge sheet (tip and/or surcharge notice) has anything to show.
    var needsPreChargeStep: Bool {
        tipEnabled || surchargeBasisPoints > 0
    }

    /// Highest accepted surcharge rate: 10000 bps = 100%. Keeps `base * bps` far from `Int`
    /// overflow.
    static let maxSurchargeBasisPoints = 10_000

    /// Copy with the free-text numeric fields forced into a range the cent math can handle.
    func sanitized() -> ChargeOptions {
        var copy = self
        copy.surchargeBasisPoints = min(max(surchargeBasisPoints, 0), Self.maxSurchargeBasisPoints)
        copy.signatureThresholdCents = min(max(signatureThresholdCents, 0), ChargeCalculator.maxAmountCents)
        return copy
    }
}

/// Persists `ChargeOptions` in UserDefaults. These are behavior toggles, not secrets, so they
/// stay out of the Keychain store that holds credentials.
enum ChargeOptionsStore {
    private static let key = "chargeOptions"

    static func load() -> ChargeOptions {
        guard let data = UserDefaults.standard.data(forKey: key),
              let options = try? JSONDecoder().decode(ChargeOptions.self, from: data)
        else {
            return ChargeOptions()
        }
        return options.sanitized()
    }

    static func save(_ options: ChargeOptions) {
        guard let data = try? JSONEncoder().encode(options) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// The amounts that go into one `startTransaction` call. `baseCents` is passed as `amount`;
/// tip and surcharge are separate parameters, never folded into the base.
struct ChargeBreakdown: Equatable {
    let baseCents: Int
    let tipCents: Int?
    let surchargeCents: Int?
    /// Local only. The demo captures a signature on screen but does not upload it, so it never
    /// sends `promptForSignature` to the SDK.
    let collectSignature: Bool

    /// What the Apple tap sheet shows: base + tip. The surcharge is never part of it.
    var tapSheetCents: Int { baseCents + (tipCents ?? 0) }
}

/// Pure cent math. All values are `Int` cents and integer division truncates, matching the
/// Checkout app (see TTP_Usecases.md sections 4 to 6).
enum ChargeCalculator {
    static let tipPercentPresets = [18, 20, 22]
    static let customTipMaxDigits = 6

    /// Largest base amount accepted from the amount field: $999,999.99.
    static let maxAmountCents = 99_999_999

    /// Converts the dollar text field to cents. Returns nil for empty, malformed, zero,
    /// negative or oversized input, and for more than two decimal places (never rounds money
    /// silently). Goes through `Decimal` because `Int(Double * 100)` truncates values such as
    /// 0.29 down to 28.
    static func amountInCents(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard !trimmed.isEmpty,
              trimmed.filter({ $0 == "." }).count <= 1,
              parts.count < 2 || parts[1].count <= 2,
              trimmed.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              let dollars = Decimal(string: trimmed)
        else {
            return nil
        }

        // At most two decimal places, so the product is a whole number of cents.
        let cents = NSDecimalNumber(decimal: dollars * 100).intValue
        return (1...maxAmountCents).contains(cents) ? cents : nil
    }

    static func tipCents(baseCents: Int, percent: Int) -> Int {
        baseCents * percent / 100
    }

    /// Surcharge on the base amount only (the tip is excluded). Nil when no rate is set, so the
    /// SDK is not handed a meaningless zero.
    static func surchargeCents(baseCents: Int, basisPoints: Int) -> Int? {
        guard basisPoints > 0 else { return nil }
        return baseCents * basisPoints / 10_000
    }

    /// `totalCents` is base + tip. Refunds never need a signature. Rule names mirror the `ALWAYS` / `NEVER` / `ON_THRESHOLD_AMOUNT`
    /// device settings; `ON_NETWORK_RECOMMENDATION` is omitted because TTP never provides the
    /// cardholder verification method it depends on.
    static func requiresSignature(
        totalCents: Int,
        rule: SignatureRule,
        thresholdCents: Int,
        isRefund: Bool = false
    ) -> Bool {
        guard !isRefund else { return false }
        switch rule {
        case .always: return true
        case .never: return false
        case .threshold: return totalCents >= thresholdCents
        }
    }

    static func surchargeNotice(basisPoints: Int, surchargeCents: Int) -> String {
        let percent = percentFormatter.string(from: NSNumber(value: Double(basisPoints) / 100.0)) ?? "\(basisPoints / 100)"
        return "A surcharge of \(percent)% (\(formatCurrency(cents: surchargeCents))) will be added if using a credit card. 0% for debit"
    }

    static func formatCurrency(cents: Int) -> String {
        currencyFormatter.string(from: NSDecimalNumber(value: cents).dividing(by: 100)) ?? "$\(cents / 100).\(String(format: "%02d", cents % 100))"
    }

    /// Custom tip keypad: digits only, capped at 6 digits. The digits are cents ("250" = $2.50).
    static func sanitizedCustomTipDigits(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber }.prefix(customTipMaxDigits))
    }

    static func customTipCents(from text: String) -> Int? {
        let digits = sanitizedCustomTipDigits(text)
        guard let cents = Int(digits), cents > 0 else { return nil }
        return cents
    }

    // MARK: - Private

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}
