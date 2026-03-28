import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ios_storekit2/ios_storekit2.dart';
import 'package:ios_storekit2/ios_storekit2_platform_interface.dart';
import 'package:ios_storekit2/ios_storekit2_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIosStorekit2Platform
    with MockPlatformInterfaceMixin
    implements IosStorekit2Platform {
  @override
  Future<List<SK2Product>> getProducts(Set<String> identifiers) async {
    return [
      const SK2Product(
        id: 'test_product',
        displayName: 'Test',
        description: 'Test product',
        type: SK2ProductType.nonConsumable,
        price: 9.99,
        currencyCode: 'USD',
      ),
    ];
  }

  @override
  Future<SK2PurchaseResult> purchase(String productId) async {
    return SK2PurchaseResult(
      status: SK2PurchaseStatus.success,
      productId: productId,
      productType: SK2ProductType.nonConsumable,
      transactionId: '1000000001',
      originalTransactionId: '1000000001',
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<List<SK2Entitlement>> getEntitlements() async {
    return [];
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Stream<SK2Entitlement> get transactionUpdates => const Stream.empty();
}

void main() {
  final IosStorekit2Platform initialPlatform = IosStorekit2Platform.instance;

  test('$MethodChannelIosStorekit2 is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelIosStorekit2>());
  });

  test('getProducts', () async {
    IosStorekit2 plugin = IosStorekit2();
    MockIosStorekit2Platform fakePlatform = MockIosStorekit2Platform();
    IosStorekit2Platform.instance = fakePlatform;

    final products = await plugin.getProducts({'test_product'});
    expect(products.length, 1);
    expect(products.first.id, 'test_product');
  });

  test('purchase', () async {
    IosStorekit2 plugin = IosStorekit2();
    MockIosStorekit2Platform fakePlatform = MockIosStorekit2Platform();
    IosStorekit2Platform.instance = fakePlatform;

    final result = await plugin.purchase('test_product');
    expect(result.status, SK2PurchaseStatus.success);
  });
}
