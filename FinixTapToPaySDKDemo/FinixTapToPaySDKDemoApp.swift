//
//  FinixTapToPaySDKDemoApp.swift
//  FinixTapToPaySDKDemo
//
//  Created by Israrul Haque on 06/04/26.
//

import SwiftUI
import FinixTapToPaySDK

@main
struct FinixTapToPaySDKDemoApp: App {
    var body: some Scene {
        WindowGroup {
            if FinixTapToPay.isSupported() {
                ContentView()
            } else {
                UnsupportedDeviceView()
            }
        }
    }
}

/// Fallback view for devices that don't support Tap to Pay
struct UnsupportedDeviceView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Tap to Pay Not Supported")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap to Pay on iPhone requires an iPhone XS or later with iOS 18.1 or later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}
