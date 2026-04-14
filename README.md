# finix-taptopay-ios-sdk-demo-app

## Overview
This repository hosts the demo application for [finix-taptopay-ios-sdk](https://github.com/finix-payments/finix-taptopay-ios-sdk)

## Installation Guide

### 1. Clone the repository:
```bash
git clone https://github.com/finix-payments/finix-taptopay-ios-sdk-demo-app.git
cd finix-taptopay-ios-sdk-demo-app
```

### 2. Open the demo project:
```bash
open FinixTapToPaySDKDemo.xcodeproj
```

### 3. Run on a physical device or simulator:

**Requirements:**
- **For Simulator**: iOS 16.4+ simulator (any iPhone model)
- **For Real Device**: iPhone XS or later running iOS 16.4+
- **Apple Developer Account**: Required for Tap to Pay entitlement

#### Running on Simulator:
1. Select any iOS Simulator (iOS 16.4+) as the run destination
2. Press ⌘R to build and run
3. The simulator fully supports Tap to Pay with simulated card reads

#### Running on Real Device:
1. Connect your iPhone XS or later (iOS 16.4+)
2. Ensure your Apple Developer account has the Tap to Pay entitlement:
   - `com.apple.developer.proximity-reader.payment.acceptance`
3. Select your device as the run destination
4. Press ⌘R to build and run

### 4. Using the App

#### Configure Credentials (Optional):
The app comes pre-configured with sandbox test credentials. To use your own credentials:

1. Tap the **menu icon (⋯)** in the top-right corner
2. Tap **Configuration**
3. Select your environment (Production, Sandbox, or QA)
4. Enter your credentials:
   - Device ID
   - Merchant ID and MID
   - API Username and Password
5. Tap **Update Configuration**

#### Initial Setup:
1. **Link Account**: Tap **Link Account** in the menu to link your Finix merchant account with Apple Tap to Pay
   - This step is required once per device
   - The app will cache the link status

2. **Prepare Reader**: Tap **Prepare Reader** in the menu to initialize the device for transactions
   - This step is required before processing transactions
   - The reader stays active until the app is terminated

#### Process a Transaction:
1. Enter transaction amount in the text field (default: $5.00)
2. Select transaction type: **Sale**, **Auth**, or **Refund**
3. Tap the **"Tap to Pay on iPhone"** button
4. Follow on-screen prompts to present a card to the device
5. View transaction results in the logs section
6. Transaction status will auto-reset after 2 seconds

#### Additional Features:
- **Clear Caches**: Tap menu → **Clear Caches** to reset account link status
- **Clear Logs**: Tap **Clear Logs** button to clear the activity log
- **Transaction Logs**: View detailed transaction information including card details, transaction ID, and transfer state

## Features

- ✅ Account linking with Apple Tap to Pay
- ✅ Reader preparation and management
- ✅ Multiple transaction types (Sale, Authorization, Refund)
- ✅ In-app configuration management
- ✅ Environment switching (Production, Sandbox, QA)
- ✅ Real-time transaction status updates
- ✅ Detailed activity logs
- ✅ Support for both iOS Simulator and real devices
- ✅ Cache management
- ✅ Error handling with descriptive messages

## Project Structure

```
finix-taptopay-ios-sdk-demo-app/
├── FinixTapToPaySDKDemo/
│   ├── FinixTapToPayDemoApp.swift      # App entry point
│   ├── Models/
│   │   └── ContentViewModel.swift      # Main ViewModel with transaction logic
│   ├── Views/
│   │   ├── ContentView.swift           # Main UI with transaction controls
│   │   └── ConfigurationView.swift     # Configuration screen
│   ├── Assets.xcassets/
│   ├── Info.plist
│   └── FinixTapToPaySDKDemo.entitlements  # Tap to Pay entitlement
├── FinixTapToPaySDKDemoTests/
├── FinixTapToPaySDKDemoUITests/
└── README.md
```

## SDK Integration

This demo app integrates the Finix Tap to Pay SDK via Swift Package Manager:

```swift
// In Xcode project settings
dependencies: [
    .package(
        url: "https://github.com/finix-payments/finix-taptopay-ios-sdk",
        branch: "main"
    )
]
```

The SDK provides:
- Account linking with Apple Tap to Pay
- Reader preparation and management
- Transaction processing (Sale, Authorization, Refund)
- Device management
- Secure API communication with DataDog logging

## Apple Tap to Pay Requirements

### Supported Devices
- iPhone XS or later
- iOS 16.4 or later
- Supported regions: United States, United Kingdom, Australia, Canada, and more

### Developer Requirements
1. Active Apple Developer Program membership
2. Tap to Pay entitlement approved by Apple:
   - `com.apple.developer.proximity-reader.payment.acceptance`
3. iOS 16.4 or later deployment target

## Troubleshooting

### "Account Not Linked" Error
- Tap menu → **Link Account** to link your merchant account
- Ensure valid Finix credentials are configured (menu → Configuration)
- Check that merchant ID and MID are correct
- Verify network connectivity

### "Prepare Failed" Error
- Ensure account is linked first
- Verify the merchant has Tap to Pay enabled in Finix dashboard
- Check device compatibility (iPhone XS or later, iOS 16.4+)

### "Transaction Failed" Error
- Ensure reader is prepared (status shows "READY")
- Select a transaction type (Sale, Auth, or Refund)
- Check amount is valid (> 0)
- On real device: ensure card is close enough to NFC reader

### Build Errors
- Ensure Xcode is up to date (Xcode 14.0+)
- Clean build folder: Product → Clean Build Folder (⌘⇧K)
- Delete derived data: ~/Library/Developer/Xcode/DerivedData
- Restart Xcode

### SPM Package Resolution Errors
- File → Packages → Reset Package Caches
- File → Packages → Update to Latest Package Versions
- Check internet connectivity
- Verify the SDK package path is correct

## Documentation

- [Finix Tap to Pay SDK Documentation](https://github.com/finix-payments/finix-taptopay-ios-sdk)
- [Finix API Documentation](https://docs.finix.com)
- [Apple Tap to Pay Documentation](https://developer.apple.com/tap-to-pay/)
- [Apple ProximityReader Framework](https://developer.apple.com/documentation/proximityreader)

## License

This demo app is provided as-is for demonstration purposes.

## Support

For support, please contact:
- Finix Support: support@finix.com
- GitHub Issues: https://github.com/finix-payments/finix-taptopay-ios-sdk-demo-app/issues
