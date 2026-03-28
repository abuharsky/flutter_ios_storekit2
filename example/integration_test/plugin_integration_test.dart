import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ios_storekit2/ios_storekit2.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getProducts returns list', (WidgetTester tester) async {
    final IosStorekit2 plugin = IosStorekit2();
    final products = await plugin.getProducts({'com.example.test'});
    expect(products, isA<List<SK2Product>>());
  });
}
