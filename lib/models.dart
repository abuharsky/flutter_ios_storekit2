enum SK2ProductType { subscription, consumable, nonConsumable }

enum SK2OfferType { freeTrial, payAsYouGo, payUpFront }

enum SK2PurchaseStatus { success, pending, cancelled }

enum SK2EligibilityStatus { eligible, ineligible, unknown }

enum SK2OwnershipType { purchased, familyShared }

enum SK2PeriodUnit { day, week, month, year }

class SK2Period {
  final int value;
  final SK2PeriodUnit unit;

  const SK2Period({required this.value, required this.unit});

  factory SK2Period.fromMap(Map<String, dynamic> map) {
    final unitName = map['unit'] as String?;
    final value = map['value'] as int?;
    if (unitName != null && value != null) {
      return SK2Period(
        value: value,
        unit: SK2PeriodUnit.values.byName(unitName),
      );
    }

    return SK2Period(
      value: (map['periodDays'] as int?) ?? 0,
      unit: SK2PeriodUnit.day,
    );
  }

  int get approximateDays {
    switch (unit) {
      case SK2PeriodUnit.day:
        return value;
      case SK2PeriodUnit.week:
        return value * 7;
      case SK2PeriodUnit.month:
        return value * 30;
      case SK2PeriodUnit.year:
        return value * 365;
    }
  }
}

class SK2IntroOfferInfo {
  final SK2OfferType offerType;
  final SK2Period period;
  final double price;
  final String currencyCode;

  const SK2IntroOfferInfo({
    required this.offerType,
    required this.period,
    required this.price,
    required this.currencyCode,
  });

  factory SK2IntroOfferInfo.fromMap(Map<String, dynamic> map) {
    return SK2IntroOfferInfo(
      offerType: SK2OfferType.values.byName(map['offerType'] as String),
      period: map['period'] != null
          ? SK2Period.fromMap(Map<String, dynamic>.from(map['period'] as Map))
          : SK2Period(
              value: (map['periodDays'] as int?) ?? 0,
              unit: SK2PeriodUnit.day,
            ),
      price: (map['price'] as num).toDouble(),
      currencyCode: map['currencyCode'] as String,
    );
  }

  bool get isTrial => offerType == SK2OfferType.freeTrial;

  int get periodDays => period.approximateDays;
}

typedef SK2TrialInfo = SK2IntroOfferInfo;

class SK2SubscriptionInfo {
  final SK2Period period;
  final bool isAutoRenewable;
  final SK2EligibilityStatus introOfferEligibility;
  final SK2IntroOfferInfo? introOffer;

  const SK2SubscriptionInfo({
    required this.period,
    required this.isAutoRenewable,
    required this.introOfferEligibility,
    this.introOffer,
  });

  factory SK2SubscriptionInfo.fromMap(Map<String, dynamic> map) {
    final legacyIsTrialEligible = map['isTrialEligible'] as bool?;
    final introOfferEligibility = map['introOfferEligibility'] != null
        ? SK2EligibilityStatus.values.byName(
            map['introOfferEligibility'] as String,
          )
        : legacyIsTrialEligible == null
        ? SK2EligibilityStatus.unknown
        : legacyIsTrialEligible
        ? SK2EligibilityStatus.eligible
        : SK2EligibilityStatus.ineligible;

    final introOfferMap = map['introOffer'] ?? map['trial'];

    return SK2SubscriptionInfo(
      period: map['period'] != null
          ? SK2Period.fromMap(Map<String, dynamic>.from(map['period'] as Map))
          : SK2Period(
              value: (map['periodDays'] as int?) ?? 0,
              unit: SK2PeriodUnit.day,
            ),
      isAutoRenewable: map['isAutoRenewable'] as bool,
      introOfferEligibility: introOfferEligibility,
      introOffer: introOfferMap != null
          ? SK2IntroOfferInfo.fromMap(
              Map<String, dynamic>.from(introOfferMap as Map),
            )
          : null,
    );
  }

  int get periodDays => period.approximateDays;

  bool? get isTrialEligible {
    switch (introOfferEligibility) {
      case SK2EligibilityStatus.eligible:
        return true;
      case SK2EligibilityStatus.ineligible:
        return false;
      case SK2EligibilityStatus.unknown:
        return null;
    }
  }

  SK2IntroOfferInfo? get trial {
    final introOffer = this.introOffer;
    if (introOffer == null || !introOffer.isTrial) {
      return null;
    }
    return introOffer;
  }
}

class SK2Product {
  final String id;
  final String displayName;
  final String description;
  final SK2ProductType type;
  final double price;
  final String currencyCode;
  final SK2SubscriptionInfo? subscription;

  const SK2Product({
    required this.id,
    required this.displayName,
    required this.description,
    required this.type,
    required this.price,
    required this.currencyCode,
    this.subscription,
  });

  factory SK2Product.fromMap(Map<String, dynamic> map) {
    return SK2Product(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      description: map['description'] as String,
      type: SK2ProductType.values.byName(map['type'] as String),
      price: (map['price'] as num).toDouble(),
      currencyCode: map['currencyCode'] as String,
      subscription: map['subscription'] != null
          ? SK2SubscriptionInfo.fromMap(
              Map<String, dynamic>.from(map['subscription'] as Map),
            )
          : null,
    );
  }
}

class SK2PurchaseResult {
  final SK2PurchaseStatus status;
  final String? productId;
  final SK2ProductType? productType;
  final String? transactionId;
  final String? originalTransactionId;
  final DateTime? purchaseDate;
  final DateTime? expirationDate;
  final DateTime? revocationDate;
  final SK2OwnershipType? ownershipType;
  final bool isIntroOffer;
  final SK2OfferType? introOfferType;

  const SK2PurchaseResult({
    required this.status,
    this.productId,
    this.productType,
    this.transactionId,
    this.originalTransactionId,
    this.purchaseDate,
    this.expirationDate,
    this.revocationDate,
    this.ownershipType,
    this.isIntroOffer = false,
    this.introOfferType,
  });

  factory SK2PurchaseResult.fromMap(Map<String, dynamic> map) {
    return SK2PurchaseResult(
      status: SK2PurchaseStatus.values.byName(map['status'] as String),
      productId: map['productId'] as String?,
      productType: _productTypeFromName(map['productType'] as String?),
      transactionId: map['transactionId'] as String?,
      originalTransactionId: map['originalTransactionId'] as String?,
      purchaseDate: _dateTimeFromMillis(map['purchaseDate']),
      expirationDate: _dateTimeFromMillis(map['expirationDate']),
      revocationDate: _dateTimeFromMillis(map['revocationDate']),
      ownershipType: _ownershipTypeFromName(map['ownershipType'] as String?),
      isIntroOffer: (map['isIntroOffer'] as bool?) ?? false,
      introOfferType: _offerTypeFromMap(map),
    );
  }

  bool get isTrial => introOfferType == SK2OfferType.freeTrial;
}

class SK2Entitlement {
  final String productId;
  final SK2ProductType? productType;
  final bool isActive;
  final String? transactionId;
  final String? originalTransactionId;
  final DateTime? purchaseDate;
  final DateTime? expirationDate;
  final DateTime? revocationDate;
  final SK2OwnershipType? ownershipType;
  final bool isIntroOffer;
  final SK2OfferType? introOfferType;
  final bool willAutoRenew;

  const SK2Entitlement({
    required this.productId,
    required this.isActive,
    this.productType,
    this.transactionId,
    this.originalTransactionId,
    this.purchaseDate,
    this.expirationDate,
    this.revocationDate,
    this.ownershipType,
    this.isIntroOffer = false,
    this.introOfferType,
    this.willAutoRenew = false,
  });

  factory SK2Entitlement.fromMap(Map<String, dynamic> map) {
    return SK2Entitlement(
      productId: map['productId'] as String,
      isActive: map['isActive'] as bool,
      productType: _productTypeFromName(map['productType'] as String?),
      transactionId: map['transactionId'] as String?,
      originalTransactionId: map['originalTransactionId'] as String?,
      purchaseDate: _dateTimeFromMillis(map['purchaseDate']),
      expirationDate: _dateTimeFromMillis(map['expirationDate']),
      revocationDate: _dateTimeFromMillis(map['revocationDate']),
      ownershipType: _ownershipTypeFromName(map['ownershipType'] as String?),
      isIntroOffer:
          (map['isIntroOffer'] as bool?) ??
          ((map['isTrial'] as bool?) ?? false),
      introOfferType: _offerTypeFromMap(map),
      willAutoRenew: (map['willAutoRenew'] as bool?) ?? false,
    );
  }

  bool get isTrial => introOfferType == SK2OfferType.freeTrial;
}

SK2ProductType? _productTypeFromName(String? name) {
  if (name == null) {
    return null;
  }

  switch (name) {
    case 'oneTime':
      return SK2ProductType.nonConsumable;
    default:
      return SK2ProductType.values.byName(name);
  }
}

SK2OwnershipType? _ownershipTypeFromName(String? name) {
  if (name == null) {
    return null;
  }

  return SK2OwnershipType.values.byName(name);
}

SK2OfferType? _offerTypeFromMap(Map<String, dynamic> map) {
  final introOfferType = map['introOfferType'] as String?;
  if (introOfferType != null) {
    return SK2OfferType.values.byName(introOfferType);
  }

  if ((map['isTrial'] as bool?) ?? false) {
    return SK2OfferType.freeTrial;
  }

  return null;
}

DateTime? _dateTimeFromMillis(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  return null;
}
