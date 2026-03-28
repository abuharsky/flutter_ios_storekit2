import 'package:flutter/services.dart';

import 'ios_storekit2_platform_interface.dart';
import 'models.dart';

class MethodChannelIosStorekit2 extends IosStorekit2Platform {
  final _methodChannel = const MethodChannel('ios_storekit2');
  final _eventChannel = const EventChannel('ios_storekit2/transactions');

  late final Stream<SK2Entitlement> _transactionStream = _eventChannel
      .receiveBroadcastStream()
      .map((event) =>
          SK2Entitlement.fromMap(Map<String, dynamic>.from(event as Map)));

  @override
  Future<List<SK2Product>> getProducts(Set<String> identifiers) async {
    final result = await _methodChannel.invokeListMethod<Map>(
      'getProducts',
      {'identifiers': identifiers.toList()},
    );
    return result
            ?.map((m) => SK2Product.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  @override
  Future<SK2PurchaseResult> purchase(String productId) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'purchase',
      {'productId': productId},
    );
    return SK2PurchaseResult.fromMap(result!);
  }

  @override
  Future<List<SK2Entitlement>> getEntitlements() async {
    final result = await _methodChannel.invokeListMethod<Map>(
      'getEntitlements',
    );
    return result
            ?.map((m) => SK2Entitlement.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  @override
  Future<void> restorePurchases() async {
    await _methodChannel.invokeMethod('restorePurchases');
  }

  @override
  Stream<SK2Entitlement> get transactionUpdates => _transactionStream;
}
