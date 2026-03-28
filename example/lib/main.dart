import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ios_storekit2/ios_storekit2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoreKit 2 Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const StorePage(),
    );
  }
}

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final _plugin = IosStorekit2();
  List<SK2Product> _products = [];
  List<SK2Entitlement> _entitlements = [];
  bool _loading = false;
  String? _error;
  StreamSubscription<SK2Entitlement>? _transactionSub;

  // Replace with your real product IDs from App Store Connect
  static const _productIds = {
    'com.example.monthly',
    'com.example.yearly',
    'com.example.lifetime',
  };

  @override
  void initState() {
    super.initState();
    _transactionSub = _plugin.transactionUpdates.listen((_) {
      _loadEntitlements();
    });
    _loadProducts();
    _loadEntitlements();
  }

  @override
  void dispose() {
    _transactionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _plugin.getProducts(_productIds);
      setState(() => _products = products);
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadEntitlements() async {
    try {
      final entitlements = await _plugin.getEntitlements();
      setState(() => _entitlements = entitlements);
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _purchase(String productId) async {
    try {
      final result = await _plugin.purchase(productId);
      if (!mounted) return;

      switch (result.status) {
        case SK2PurchaseStatus.success:
          _loadEntitlements();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Purchase successful!')));
        case SK2PurchaseStatus.pending:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase pending approval.')),
          );
        case SK2PurchaseStatus.cancelled:
          break;
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _restore() async {
    try {
      await _plugin.restorePurchases();
      await _loadEntitlements();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Purchases restored.')));
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: ${e.message}')));
    }
  }

  bool _isOwned(String productId) {
    return _entitlements.any((e) => e.productId == productId && e.isActive);
  }

  String _formatPeriod(SK2Period period) {
    final unit = switch (period.unit) {
      SK2PeriodUnit.day => 'day',
      SK2PeriodUnit.week => 'week',
      SK2PeriodUnit.month => 'month',
      SK2PeriodUnit.year => 'year',
    };

    final label = period.value == 1 ? unit : '${unit}s';
    return '${period.value} $label';
  }

  String? _buildIntroOfferLabel(SK2SubscriptionInfo subscription) {
    final introOffer = subscription.introOffer;
    if (introOffer == null) {
      return null;
    }

    final offerLabel = switch (introOffer.offerType) {
      SK2OfferType.freeTrial =>
        '${_formatPeriod(introOffer.period)} free trial',
      SK2OfferType.payAsYouGo =>
        'intro offer: ${introOffer.price} ${introOffer.currencyCode} per ${_formatPeriod(introOffer.period)}',
      SK2OfferType.payUpFront =>
        'intro offer: ${introOffer.price} ${introOffer.currencyCode} for ${_formatPeriod(introOffer.period)}',
    };

    final eligibilityLabel = switch (subscription.introOfferEligibility) {
      SK2EligibilityStatus.eligible => 'available',
      SK2EligibilityStatus.ineligible => 'used',
      SK2EligibilityStatus.unknown => 'eligibility unknown',
    };

    return '$offerLabel ($eligibilityLabel)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StoreKit 2 Demo'),
        actions: [
          TextButton(onPressed: _restore, child: const Text('Restore')),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(child: Text('No products available.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadProducts(), _loadEntitlements()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_entitlements.isNotEmpty) ...[
            _buildEntitlementsSection(),
            const SizedBox(height: 24),
          ],
          _buildProductsSection(),
        ],
      ),
    );
  }

  Widget _buildEntitlementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Purchases',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ..._entitlements.where((e) => e.isActive).map((e) {
          return Card(
            child: ListTile(
              leading: Icon(
                e.isTrial ? Icons.card_giftcard : Icons.check_circle,
                color: Colors.green,
              ),
              title: Text(e.productId),
              subtitle: Text(
                [
                  if (e.isTrial) 'Trial',
                  if (e.isIntroOffer && !e.isTrial) 'Intro offer',
                  if (e.willAutoRenew) 'Auto-renewing',
                  if (e.expirationDate != null)
                    'Expires: ${e.expirationDate!.toLocal().toString().split('.').first}',
                ].join(' · '),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Products', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._products.map((product) {
          final owned = _isOwned(product.id);
          final subscription = product.subscription;
          final introOfferLabel = subscription == null
              ? null
              : _buildIntroOfferLabel(subscription);
          return Card(
            child: ListTile(
              title: Text(product.displayName),
              subtitle: Text(
                [
                  product.description,
                  if (subscription != null) ...[
                    _formatPeriod(subscription.period),
                    if (subscription.isAutoRenewable) 'auto-renewable',
                    if (introOfferLabel != null) introOfferLabel,
                  ],
                ].join(' · '),
              ),
              trailing: owned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : ElevatedButton(
                      onPressed: () => _purchase(product.id),
                      child: Text('${product.price} ${product.currencyCode}'),
                    ),
            ),
          );
        }),
      ],
    );
  }
}
