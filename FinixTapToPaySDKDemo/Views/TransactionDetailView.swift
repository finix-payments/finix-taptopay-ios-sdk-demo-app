//
//  TransactionDetailView.swift
//  FinixTapToPaySDKDemo
//

import SwiftUI
import UIKit

/// Full breakdown of the last charge, opened from the `transaction:` row on the main screen.
/// The SDK result carries only the total (base + tip), so base, tip and surcharge come from what
/// this app passed in.
struct TransactionDetailView: View {
    let summary: TransactionSummary

    var body: some View {
        Form {
            Section(header: Text("AMOUNTS")) {
                row("Type", summary.type.displayName)
                row("Base", money(summary.breakdown.baseCents))
                row("Tip", summary.breakdown.tipCents.map(money) ?? "None")
                row("Surcharge", summary.breakdown.surchargeCents.map { "\(money($0)) requested" } ?? "None")
                row("Total (tap sheet)", money(summary.totalCents))

                if summary.breakdown.surchargeCents != nil {
                    Text("The surcharge is applied by Finix to credit cards only and is not part of the total above.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("REFERENCES")) {
                if let brand = summary.cardBrand, let last4 = summary.last4 {
                    row("Card", "\(brand) •••• \(last4)")
                }
                row("Transfer ID", summary.transferId ?? "N/A")
                row("Trace ID", summary.traceId ?? "N/A")
            }

            if summary.breakdown.collectSignature {
                Section(header: Text("SIGNATURE")) {
                    signatureContent
                }
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var signatureContent: some View {
        if let png = summary.signaturePNG, let image = UIImage(data: png) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(uiColor: .separator)))
                Text("Captured locally, not uploaded")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } else {
            row("Signature", "Requested, none captured")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private func money(_ cents: Int) -> String {
        ChargeCalculator.formatCurrency(cents: cents)
    }
}
