import 'ios_storekit2_platform_interface.dart';
import 'models.dart';

export 'models.dart';

class IosStorekit2 {
  Future<List<SK2Product>> getProducts(Set<String> identifiers) {
    return IosStorekit2Platform.instance.getProducts(identifiers);
  }

  Future<SK2PurchaseResult> purchase(String productId) {
    return IosStorekit2Platform.instance.purchase(productId);
  }

  Future<List<SK2Entitlement>> getEntitlements() {
    return IosStorekit2Platform.instance.getEntitlements();
  }

  Future<void> restorePurchases() {
    return IosStorekit2Platform.instance.restorePurchases();
  }

  Stream<SK2Entitlement> get transactionUpdates {
    return IosStorekit2Platform.instance.transactionUpdates;
  }
}
