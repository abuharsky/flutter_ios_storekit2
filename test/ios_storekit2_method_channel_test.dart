import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_storekit2/ios_storekit2_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelIosStorekit2 platform = MethodChannelIosStorekit2();
  const MethodChannel channel = MethodChannel('ios_storekit2');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getProducts':
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
          };
        case 'getEntitlements':
          return <Map>[];
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

  test('purchase', () async {
    final result = await platform.purchase('test');
    expect(result.status.name, 'success');
  });

  test('getEntitlements', () async {
    final entitlements = await platform.getEntitlements();
    expect(entitlements, isEmpty);
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
