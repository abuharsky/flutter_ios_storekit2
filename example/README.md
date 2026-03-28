# ios_storekit2_example

Demonstrates how to use the `ios_storekit2` plugin and includes a local StoreKit test setup for Xcode.

## Quick Start

1. Run `flutter pub get` in the package root.
2. Open `example/ios/Runner.xcworkspace` in Xcode.
3. Select the shared `Runner` scheme.
4. Run the app from Xcode when you want to test purchases. The scheme is already linked to `Runner/Configuration.storekit`.

`flutter run` is still fine for normal UI work, but Xcode should be used for local StoreKit purchase flows because the StoreKit scheme configuration is applied there.

## Included Local Products

- `com.example.monthly`: auto-renewable monthly subscription with a 7-day free trial
- `com.example.yearly`: auto-renewable yearly subscription
- `com.example.lifetime`: non-consumable lifetime unlock

These product IDs match the IDs used in `example/lib/main.dart`.

## Automated Xcode Tests

The `RunnerTests` target now uses `StoreKitTest` and `SKTestSession` with the local `Configuration.storekit` file.

Run them from Xcode:

1. Open `Product > Test`.
2. Or run just the `RunnerTests` target from the Test navigator.

Covered scenarios:

- product loading and StoreKit metadata mapping
- successful non-consumable purchase
- Ask to Buy pending -> approve
- Ask to Buy pending -> decline
- refund / revocation handling
- subscription expiration
- forced subscription renewal
- restore purchases

## Manual Scenario Matrix

Use Xcode's Transaction Manager while the app is running with the `Runner` scheme:

- refund a transaction and verify `transactionUpdates`
- expire a subscription and verify entitlements refresh correctly
- approve or decline Ask to Buy requests
- force subscription renewals
- disable auto-renew for an active subscription
- test interrupted purchases
- test billing retry and grace period
- test price increase consent flows

For billing retry, grace period, interrupted purchases, and price increase consent, `SKTestSession` already supports the underlying toggles, but the current plugin API does not expose all of those states directly, so those flows are best validated manually in Xcode as well.
