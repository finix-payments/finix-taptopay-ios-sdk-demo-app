//
//  PreChargeView.swift
//  FinixTapToPaySDKDemo
//

import SwiftUI

/// Tip selection followed by the surcharge notice. Mirrors the Checkout app's pre-charge screens;
/// the host app owns both, the SDK only receives the resulting amounts.
struct PreChargeView: View {

    private enum Step {
        case tip
        case customTip
        case surchargeNotice
    }

    let charge: PendingCharge
    let options: ChargeOptions
    /// Called with the chosen tip in cents (nil = no tip) once the user has been through every step.
    let onConfirm: (Int?) -> Void

    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var step: Step
    @State private var tipCents: Int?
    @State private var customDigits = ""

    init(charge: PendingCharge, options: ChargeOptions, onConfirm: @escaping (Int?) -> Void) {
        self.charge = charge
        self.options = options
        self.onConfirm = onConfirm
        _step = State(initialValue: options.tipEnabled ? .tip : .surchargeNotice)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .tip: tipStep
                case .customTip: customTipStep
                case .surchargeNotice: noticeStep
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        switch step {
        case .tip: return "Add a Tip"
        case .customTip: return "Custom Tip"
        case .surchargeNotice: return "Surcharge"
        }
    }

    // MARK: - Tip

    private var tipStep: some View {
        Form {
            Section(header: Text("Sale amount \(ChargeCalculator.formatCurrency(cents: charge.baseCents))")) {
                ForEach(ChargeCalculator.tipPercentPresets, id: \.self) { percent in
                    let cents = ChargeCalculator.tipCents(baseCents: charge.baseCents, percent: percent)
                    Button("\(percent)% (\(ChargeCalculator.formatCurrency(cents: cents)))") {
                        chooseTip(cents)
                    }
                }
                Button("Custom Tip") {
                    customDigits = ""
                    step = .customTip
                }
                Button("No Tip") {
                    chooseTip(nil)
                }
            }
        }
    }

    private var customTipStep: some View {
        let cents = ChargeCalculator.customTipCents(from: customDigits)

        return Form {
            Section(
                header: Text("Enter digits as cents"),
                footer: Text("Up to \(ChargeCalculator.customTipMaxDigits) digits. 250 is $2.50.")
            ) {
                TextField("0", text: $customDigits)
                    .keyboardType(.numberPad)
                    .onChange(of: customDigits) { _, newValue in
                        let sanitized = ChargeCalculator.sanitizedCustomTipDigits(newValue)
                        if sanitized != newValue { customDigits = sanitized }
                    }

                Text(ChargeCalculator.formatCurrency(cents: cents ?? 0))
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Next") {
                    if let cents { chooseTip(cents) }
                }
                .disabled(cents == nil)

                Button("Back") { step = .tip }
            }
        }
    }

    // MARK: - Surcharge notice

    private var noticeStep: some View {
        let surcharge = ChargeCalculator.surchargeCents(
            baseCents: charge.baseCents,
            basisPoints: options.surchargeBasisPoints
        ) ?? 0

        return Form {
            Section {
                Text(ChargeCalculator.surchargeNotice(
                    basisPoints: options.surchargeBasisPoints,
                    surchargeCents: surcharge
                ))
            }

            Section {
                FinixButton(title: "Continue") { onConfirm(tipCents) }
                    .listRowInsets(EdgeInsets())

                if options.tipEnabled {
                    Button("Back") { step = .tip }
                }
            }
        }
    }

    // MARK: - Actions

    private func chooseTip(_ cents: Int?) {
        tipCents = cents
        if options.surchargeBasisPoints > 0 {
            step = .surchargeNotice
        } else {
            onConfirm(cents)
        }
    }
}
