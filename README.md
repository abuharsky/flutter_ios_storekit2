# ios_storekit2

Flutter plugin for iOS in-app purchases powered by StoreKit 2.

## Scope

- iOS only
- Minimum iOS version: 15.0
- Product loading
- Purchasing
- Current entitlements
- Restore purchases
- Transaction updates stream
- StoreKit Test coverage in the `example` app

## Install

```yaml
dependencies:
  ios_storekit2:
    path: ../ios_storekit2
```

## Basic Usage

```dart
import 'package:ios_storekit2/ios_storekit2.dart';

final storekit = IosStorekit2();

final products = await storekit.getProducts({
  'com.example.monthly',
  'com.example.yearly',
  'com.example.lifetime',
});

final result = await storekit.purchase('com.example.monthly');

if (result.status == SK2PurchaseStatus.success) {
  print(result.transactionId);
  print(result.productType);
}

final entitlements = await storekit.getEntitlements();
```

## Error Details

Native iOS failures still use plugin-level `PlatformException.code` values such as
`FETCH_ERROR`, `PURCHASE_ERROR`, and `RESTORE_ERROR`, but now also include the
underlying `NSError` metadata in `PlatformException.details`:

- `nativeErrorDomain`
- `nativeErrorCode`
- `nativeLocalizedDescription`
- `nativeLocalizedFailureReason`
- `nativeLocalizedRecoverySuggestion`
- `nativeHelpAnchor`
- `nativeErrorUserInfo` as a Flutter-safe serialized map
- `underlyingURLError` when StoreKit surfaces a nested network transport error

```dart
try {
  await storekit.restorePurchases();
} on PlatformException catch (e) {
  final details = (e.details as Map?)?.cast<String, dynamic>();
  print(e.code); // RESTORE_ERROR
  print(details?['nativeErrorDomain']);
  print(details?['nativeErrorCode']);
  print(details?['nativeLocalizedFailureReason']);
  print(details?['nativeErrorUserInfo']);
  print(details?['underlyingURLError']);
}
```

## Product Model

- `SK2ProductType` now distinguishes `subscription`, `consumable`, and `nonConsumable`
- Subscription periods are exposed canonically as `SK2Period(value, unit)`
- Introductory offers are exposed as `introOffer`, not only as trial-specific data

Example:

```dart
for (final product in products) {
  final subscription = product.subscription;
  if (subscription == null) continue;

  final period = subscription.period;
  print('${period.value} ${period.unit.name}');

  final introOffer = subscription.introOffer;
  if (introOffer != null) {
    print(introOffer.offerType);
  }
}
```

## Intro Offers And Trial Sugar

The canonical fields are:

- `subscription.introOffer`
- `subscription.introOfferEligibility`
- `purchaseResult.isIntroOffer`
- `purchaseResult.introOfferType`
- `entitlement.isIntroOffer`
- `entitlement.introOfferType`

Convenience sugar is still available:

- `subscription.trial` returns the intro offer only when it is a free trial
- `subscription.isTrialEligible` maps eligibility to `bool?`
- `purchaseResult.isTrial` is `true` only for free trials
- `entitlement.isTrial` is `true` only for free trials
- `SK2TrialInfo` remains available as a typedef alias to `SK2IntroOfferInfo`

`isTrialEligible` is now nullable:

- `true`: eligible
- `false`: not eligible
- `null`: eligibility is unknown, for example on iOS 15

## Purchase Result

Successful purchases now return richer metadata:

- `productId`
- `productType`
- `transactionId`
- `originalTransactionId`
- `purchaseDate`
- `expirationDate`
- `revocationDate`
- `ownershipType`
- `isIntroOffer`
- `introOfferType`

This makes it easier to log, deduplicate, and reconcile purchases in app code.

## Migration Notes

### 1. `SK2ProductType.oneTime` was removed

Before:

```dart
if (product.type == SK2ProductType.oneTime) {
  // ...
}
```

After:

```dart
if (product.type == SK2ProductType.nonConsumable) {
  // ...
}
```

If you need consumables, check `SK2ProductType.consumable`.

### 2. Use `period`, not `periodDays`, as the source of truth

Before:

```dart
final days = product.subscription!.periodDays;
```

After:

```dart
final period = product.subscription!.period;
final value = period.value;
final unit = period.unit;
```

`periodDays` still exists as a convenience getter, but it is only an approximation.

### 3. Use intro-offer APIs instead of assuming every offer is a free trial

Before:

```dart
final trial = product.subscription?.trial;
if (trial != null) {
  print('${trial.periodDays}-day trial');
}
```

After:

```dart
final introOffer = product.subscription?.introOffer;
if (introOffer != null) {
  print(introOffer.offerType);
}
```

`trial` is still available, but only for free trials.

### 4. `isTrialEligible` is now `bool?`

Before:

```dart
if (product.subscription!.isTrialEligible) {
  // show trial CTA
}
```

After:

```dart
switch (product.subscription!.introOfferEligibility) {
  case SK2EligibilityStatus.eligible:
    // show intro offer
    break;
  case SK2EligibilityStatus.ineligible:
    // already used
    break;
  case SK2EligibilityStatus.unknown:
    // platform cannot determine
    break;
}
```

### 5. Purchase payloads are richer now

Before:

```dart
final result = await storekit.purchase(product.id);
print(result.productId);
```

After:

```dart
final result = await storekit.purchase(product.id);
print(result.productId);
print(result.transactionId);
print(result.originalTransactionId);
print(result.productType);
```

## Testing

The `example` app includes StoreKit Test setup and Xcode unit tests for:

- product mapping
- purchase success
- Ask to Buy approve / decline
- restore purchases
- refund / revocation
- expiration
- renewal
- intro offer eligibility

See `example/ios/RunnerTests/RunnerTests.swift`.
