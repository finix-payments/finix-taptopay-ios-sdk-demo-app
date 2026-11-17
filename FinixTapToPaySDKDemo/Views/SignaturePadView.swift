//
//  SignaturePadView.swift
//  FinixTapToPaySDKDemo
//

import SwiftUI
import UIKit

/// Finger-drawn signature pad. The Tap to Pay SDK has no signature UI, so capture is entirely
/// host-app code: each inner array of `strokes` is one continuous stroke.
struct SignaturePadView: View {
    static let height: CGFloat = 240

    @Binding var strokes: [[CGPoint]]
    /// Pad size in points, kept so the PNG render can use the same coordinate space.
    @Binding var drawingSize: CGSize?

    @State private var isDrawing = false

    var body: some View {
        ZStack {
            Canvas { context, _ in
                for stroke in strokes where stroke.count > 1 {
                    var path = Path()
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(.primary),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            if strokes.isEmpty {
                Text("Sign Here")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .separator)))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { drawingSize = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in drawingSize = newSize }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if isDrawing, !strokes.isEmpty {
                        strokes[strokes.count - 1].append(value.location)
                    } else {
                        strokes.append([value.location])
                        isDrawing = true
                    }
                }
                .onEnded { _ in
                    // The next touch starts a new stroke, so no line joins separate strokes.
                    isDrawing = false
                }
        )
    }
}

enum SignatureRenderer {
    private static let fallbackSize = CGSize(width: 400, height: SignaturePadView.height)

    /// Renders the strokes as a white-background PNG at 2x with 2 pt round lines.
    /// Returns nil when there is nothing to draw (fewer than two points in total).
    static func pngData(strokes: [[CGPoint]], size: CGSize?) -> Data? {
        guard strokes.reduce(0, { $0 + $1.count }) > 1 else { return nil }

        let size = size ?? fallbackSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIColor.white.setFill()
            renderer.fill(CGRect(origin: .zero, size: size))

            let context = renderer.cgContext
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(2)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            for stroke in strokes where stroke.count > 1 {
                context.move(to: stroke[0])
                for point in stroke.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }
        }
        return image.pngData()
    }
}
