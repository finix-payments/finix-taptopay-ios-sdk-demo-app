# Finix Tap to Pay — iOS Demo App

A runnable sample integration of [FinixTapToPaySDK](https://github.com/finix-payments/finix-taptopay-ios-sdk), Finix's Tap to Pay on iPhone SDK. It links a merchant's Apple ID, prepares the iPhone's built-in card reader, and takes sale, authorization, and refund payments with a live activity log.

## Requirements

| | |
|---|---|
| Device | Physical iPhone XS or newer running iOS 18.1+ |
| Xcode | 16.1 or later |
| Apple | Developer account with the Tap to Pay entitlement `com.apple.developer.proximity-reader.payment.acceptance` |
| Finix | API username & password, merchant ID, MID, merchant name, and an activated `IOS_TAP_TO_PAY` device ID |

Tap to Pay on iPhone does not run in the Simulator — the app builds and launches there, but `FinixTapToPay.isSupported()` returns `false` and an unsupported-device screen is shown. Use a physical iPhone.

The SDK README has step-by-step walkthroughs for both prerequisites: [requesting the Apple entitlement](https://github.com/finix-payments/finix-taptopay-ios-sdk#apple-entitlement-and-infoplist) and [provisioning the Finix device](https://github.com/finix-payments/finix-taptopay-ios-sdk#device-provisioning).

## Getting started

1. Clone and open the project — Swift Package Manager resolves the SDK automatically:

   ```bash
   git clone https://github.com/finix-payments/finix-taptopay-ios-sdk-demo-app.git
   cd finix-taptopay-ios-sdk-demo-app
   open FinixTapToPaySDKDemo.xcodeproj
   ```

2. In **Signing & Capabilities**, select your own team and bundle identifier — the provisioning profile must carry the Tap to Pay entitlement (the committed project references Finix's team).

3. Select a connected iPhone as the run destination and press ⌘R.

## Configuring credentials

The app ships with no credentials and starts as **Not Configured**:

1. Tap the **⋯ menu** (top right) → **Configuration**.
2. Pick the environment — **Sandbox** (default) or **Production**.
3. Enter your device ID, merchant ID / MID / name, and API username / password.
4. Tap **Save**.

Saved values persist across launches, kept separately per environment in the iOS Keychain — switching the environment picker loads whatever was last saved for that environment. Nothing is written to source control.

## Taking a payment

1. **Link Account** (⋯ menu) — links the device's signed-in Apple ID to the merchant. Required once per device, and "account already linked" is treated as success. Tap to Pay registers the device to that Apple ID, so testing another merchant or environment on the same phone means switching Apple IDs.
2. **Prepare** (status section) — warms up the reader. The status shows **"Tap to Pay on iPhone is READY"** when done.
3. Enter an amount, choose **Sale**, **Auth**, or **Refund**, then tap **Tap to Pay on iPhone** and present a card.
4. The result — card details, Finix transfer ID, and transfer state — appears in the logs section.

Also available: **Clear Caches** (⋯ menu) resets the cached Apple ID link status, and the **Clear** button empties the log.

## Project structure

| File | Role |
|---|---|
| `FinixTapToPaySDKDemoApp.swift` | App entry point; unsupported-device screen |
| `Views/ContentView.swift` | Main flow — status, transaction type, amount, logs |
| `Views/ConfigurationView.swift` | Environment and credential entry |
| `Models/ContentViewModel.swift` | SDK wiring and transaction logic |
| `Models/SavedConfigurationStore.swift` | Per-environment credential persistence (Keychain) |

## Troubleshooting

| Symptom | Cause |
|---|---|
| "Tap to Pay Not Supported" screen | Running in the Simulator, on an iPhone older than XS, or on iOS below 18.1 |
| "Not Configured" status | No saved credentials for the selected environment — open Configuration and Save |
| Link fails, or Apple's terms sheet never appears | No Apple ID signed in on the device |
| Prepare fails | Provisioning profile lacks the Tap to Pay entitlement |
| Transaction fails mentioning activation | The device ID was created but never activated — see [Device provisioning](https://github.com/finix-payments/finix-taptopay-ios-sdk#device-provisioning) |
| Token fetch fails | Credentials don't match the selected environment, or the MID isn't provisioned for Tap to Pay |

## Documentation

- [FinixTapToPaySDK README](https://github.com/finix-payments/finix-taptopay-ios-sdk) — full quick start, API overview, and error reference
- [Finix API documentation](https://docs.finix.com)
- [Apple: Tap to Pay on iPhone](https://developer.apple.com/tap-to-pay/)

## Support

Contact your Finix point of contact.

## License

The demo source is provided as a reference for building your own integration. Use of the Finix Tap to Pay SDK is governed by your Finix services agreement — see the [SDK license](https://github.com/finix-payments/finix-taptopay-ios-sdk/blob/main/LICENSE).
