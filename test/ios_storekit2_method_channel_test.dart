import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_storekit2/ios_storekit2_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelIosStorekit2 platform = MethodChannelIosStorekit2();
  const MethodChannel channel = MethodChannel('ios_storekit2');

  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'getProducts':
          return <Map>[
            {
              'id': 'test',
              'displayName': 'Test',
              'description': 'A test product',
              'type': 'subscription',
              'price': 9.99,
              'displayPrice': r'$9.99',
              'currencyCode': 'USD',
              'subscription': {
                'isAutoRenewable': true,
                'introOfferEligibility': 'eligible',
                'period': {'value': 1, 'unit': 'month'},
                'introOffer': {
                  'offerType': 'freeTrial',
                  'price': 0.0,
                  'displayPrice': r'$0.00',
                  'currencyCode': 'USD',
                  'period': {'value': 7, 'unit': 'day'},
                },
              },
            },
          ];
        case 'purchase':
          return {
            'status': 'success',
            'productId': 'test',
            'productType': 'nonConsumable',
            'transactionId': '1000000001',
            'originalTransactionId': '1000000001',
            'purchaseDate': 0,
            'ownershipType': 'purchased',
            'isIntroOffer': false,
            'appAccountToken': methodCall.arguments['appAccountToken'],
          };
        case 'getEntitlements':
          return <Map>[
            {
              'productId': 'test',
              'isActive': true,
              'appAccountToken': '00000000-0000-0000-0000-000000000042',
            },
          ];
        case 'getStorefront':
          return {
            'countryCode': 'USA',
            'id': '143441',
          };
        case 'restorePurchases':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getProducts', () async {
    final products = await platform.getProducts({'test'});
    expect(products.length, 1);
    expect(products.first.id, 'test');
  });

  test('getProducts parses displayPrice', () async {
    final products = await platform.getProducts({'test'});
    expect(products.first.displayPrice, r'$9.99');
    expect(products.first.subscription?.introOffer?.displayPrice, r'$0.00');
  });

  test('getProducts tolerates missing displayPrice', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return <Map>[
        {
          'id': 'test',
          'displayName': 'Test',
          'description': 'A test product',
          'type': 'nonConsumable',
          'price': 9.99,
          'currencyCode': 'USD',
        },
      ];
    });

    final products = await platform.getProducts({'test'});
    expect(products.first.displayPrice, isNull);
  });

  test('purchase', () async {
    final result = await platform.purchase('test');
    expect(result.status.name, 'success');
    expect(result.appAccountToken, isNull);
    expect(
      log.single.arguments,
      {'productId': 'test'},
    );
  });

  test('purchase passes appAccountToken to the channel', () async {
    const token = '123e4567-e89b-12d3-a456-426614174000';
    final result = await platform.purchase('test', appAccountToken: token);
    expect(result.appAccountToken, token);
    expect(
      log.single.arguments,
      {'productId': 'test', 'appAccountToken': token},
    );
  });

  test('getEntitlements', () async {
    final entitlements = await platform.getEntitlements();
    expect(entitlements.length, 1);
    expect(entitlements.first.productId, 'test');
    expect(
      entitlements.first.appAccountToken,
      '00000000-0000-0000-0000-000000000042',
    );
  });

  test('getStorefront', () async {
    final storefront = await platform.getStorefront();
    expect(storefront?.countryCode, 'USA');
    expect(storefront?.id, '143441');
  });

  test('getStorefront returns null when native has no storefront', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });

    final storefront = await platform.getStorefront();
    expect(storefront, isNull);
  });

  test('restorePurchases', () async {
    await platform.restorePurchases();
  });

  test('restorePurchases preserves native error details', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'restorePurchases') {
        throw PlatformException(
          code: 'RESTORE_ERROR',
          message: 'Restore failed',
          details: {
            'nativeErrorDomain': 'SKErrorDomain',
            'nativeErrorCode': 7,
            'nativeLocalizedDescription': 'Restore failed',
            'nativeLocalizedFailureReason': 'Not signed in',
            'nativeLocalizedRecoverySuggestion': 'Open Settings and sign in',
            'nativeErrorUserInfo': {
              'productIds': ['com.example.monthly'],
              'retryAfter': 30,
            },
          },
        );
      }
      return null;
    });

    await expectLater(
      platform.restorePurchases(),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'RESTORE_ERROR')
            .having((e) => e.message, 'message', 'Restore failed')
            .having(
              (e) => (e.details as Map)['nativeErrorDomain'],
              'nativeErrorDomain',
              'SKErrorDomain',
            )
            .having(
              (e) => (e.details as Map)['nativeErrorCode'],
              'nativeErrorCode',
              7,
            )
            .having(
              (e) => (e.details as Map)['nativeLocalizedFailureReason'],
              'nativeLocalizedFailureReason',
              'Not signed in',
            )
            .having(
              (e) => ((e.details as Map)['nativeErrorUserInfo']
                  as Map)['retryAfter'],
              'nativeErrorUserInfo.retryAfter',
              30,
            ),
      ),
    );
  });
}
