//
//  SignatureCaptureView.swift
//  FinixTapToPaySDKDemo
//

import SwiftUI

/// Shown after a successful charge when the signature rule applies. Next is never blocked and a
/// blank signature is allowed, as in the Checkout app. The PNG is kept locally: this demo does
/// not upload it.
struct SignatureCaptureView: View {
    let request: SignatureRequest
    /// PNG data, or nil when the pad was left blank.
    let onNext: (Data?) -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var drawingSize: CGSize?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ChargeCalculator.formatCurrency(cents: request.totalCents))
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    if let last4 = request.last4 {
                        Text("\(request.cardBrand ?? "Card") •••• \(last4)")
                            .foregroundColor(.secondary)
                    }
                }

                SignaturePadView(strokes: $strokes, drawingSize: $drawingSize)

                Text("I agree to pay the above total amount according to my card issuer agreement.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    FinixButton(title: "Clear Signature", style: .secondary) {
                        strokes = []
                    }
                    FinixButton(title: "Next") {
                        onNext(SignatureRenderer.pngData(strokes: strokes, size: drawingSize))
                    }
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Next is the only way out, so the signature step cannot be dismissed by accident.
        .interactiveDismissDisabled()
    }
}
