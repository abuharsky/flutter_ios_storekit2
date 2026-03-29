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
