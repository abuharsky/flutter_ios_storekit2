import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ios_storekit2_method_channel.dart';
import 'models.dart';

abstract class IosStorekit2Platform extends PlatformInterface {
  IosStorekit2Platform() : super(token: _token);

  static final Object _token = Object();

  static IosStorekit2Platform _instance = MethodChannelIosStorekit2();

  static IosStorekit2Platform get instance => _instance;

  static set instance(IosStorekit2Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<SK2Product>> getProducts(Set<String> identifiers);

  Future<SK2PurchaseResult> purchase(String productId);

  Future<List<SK2Entitlement>> getEntitlements();

  Future<void> restorePurchases();

  Stream<SK2Entitlement> get transactionUpdates;
}
