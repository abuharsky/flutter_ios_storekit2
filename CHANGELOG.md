## 0.0.7

- Added: Swift Package Manager support via `ios/ios_storekit2/Package.swift`; the plugin now builds under both SPM and CocoaPods
- Changed: iOS sources moved from `ios/Classes/` to `ios/ios_storekit2/Sources/ios_storekit2/`, and the podspec updated to match
- Changed: the `PrivacyInfo.xcprivacy` manifest is now bundled by both build systems instead of being shipped unused

## 0.0.6

- Added: `periodCount` on `SK2IntroOfferInfo`, carrying the number of billing cycles a pay-as-you-go intro offer runs for; it defaults to `1` when paired with older native code

## 0.0.5

- Added: `getStorefront()` returning `SK2Storefront` with the raw StoreKit `countryCode` (ISO 3166-1 alpha-3, e.g. `USA`) and storefront `id`
- Added: optional `appAccountToken` parameter in `purchase()`; a non-UUID string fails with `INVALID_ARGS`
- Added: nullable `appAccountToken` on `SK2PurchaseResult` and `SK2Entitlement`, populated from the transaction
- Added: nullable localized `displayPrice` on `SK2Product` and `SK2IntroOfferInfo`

## 0.0.4

- Fixed: StoreKit 2 `networkError` failures now include nested `underlyingURLError` details inside `PlatformException.details`

## 0.0.3

- Fixed: native iOS failures now include rich `NSError` details in `PlatformException.details`, including domain, code, localized fields, and serialized `userInfo`

## 0.0.2

- Compatibility: lowered the package SDK constraint to `>=3.0.0 <4.0.0`
- Compatibility: lowered `flutter_lints` in the package and example so the repo resolves on Dart 3.0 toolchains
- Breaking: `SK2ProductType.oneTime` was replaced with `SK2ProductType.consumable` and `SK2ProductType.nonConsumable`
- Breaking: subscription periods are now exposed canonically as `SK2Period(value, unit)`; `periodDays` remains only as derived sugar
- Breaking: intro offer eligibility is now modeled as `SK2EligibilityStatus`, while `isTrialEligible` becomes `bool?`
- Added: canonical intro-offer fields `introOffer`, `introOfferEligibility`, `isIntroOffer`, and `introOfferType`
- Added: richer purchase payloads with product type, transaction ids, ownership type, and purchase-related dates
- Fixed: `willAutoRenew` now matches the current subscription transaction instead of using the first status in the group
- Fixed: iOS 15 no longer reports unknown intro-offer eligibility as `false`
- Docs: README now includes setup, usage, and migration notes for the new API

## 0.0.1

- Initial plugin scaffold
