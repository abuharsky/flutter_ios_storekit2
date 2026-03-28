import StoreKit

@available(iOS 15.0, *)
class StoreKit2Manager {
    private var updateListenerTask: Task<Void, Never>?
    private var transactionSink: (([String: Any]) -> Void)?

    init() {
        startTransactionListener()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func setTransactionSink(_ sink: (([String: Any]) -> Void)?) {
        transactionSink = sink
    }

    // MARK: - Fetch Products

    func fetchProducts(products: [Product]) -> [[String: Any]] {
        return products.map { mapProduct($0) }
    }

    // MARK: - Purchase

    func purchase(productID: String) async throws -> [String: Any] {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreKit2Error.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)
            let payload = await purchaseResultMap(for: transaction, product: product)
            await transaction.finish()
            return payload

        case .userCancelled:
            return [
                "status": "cancelled",
                "productId": productID,
                "productType": productTypeName(product.type),
            ]

        case .pending:
            return [
                "status": "pending",
                "productId": productID,
                "productType": productTypeName(product.type),
            ]

        @unknown default:
            throw StoreKit2Error.unknown
        }
    }

    // MARK: - Current Entitlements

    func currentEntitlements() async -> [[String: Any]] {
        var transactions: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerification(result) else { continue }
            transactions.append(transaction)
        }

        let productsByID = await loadProductsByID(Set(transactions.map(\.productID)))
        var entitlements: [[String: Any]] = []
        entitlements.reserveCapacity(transactions.count)

        for transaction in transactions {
            let product = productsByID[transaction.productID]
            entitlements.append(await entitlementMap(for: transaction, product: product))
        }

        return entitlements
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    // MARK: - Trial Eligibility

    func updateTrialEligibility(_ productMaps: inout [[String: Any]], products: [Product]) async {
        for (index, product) in products.enumerated() {
            guard product.type == .autoRenewable || product.type == .nonRenewable,
                  var subInfo = productMaps[index]["subscription"] as? [String: Any] else {
                continue
            }

            let introOfferEligibility: String

            if product.subscription?.introductoryOffer == nil {
                introOfferEligibility = "unknown"
            } else if #available(iOS 16.0, *) {
                let eligible = await product.subscription?.isEligibleForIntroOffer ?? false
                introOfferEligibility = eligible ? "eligible" : "ineligible"
            } else {
                introOfferEligibility = "unknown"
            }

            subInfo["introOfferEligibility"] = introOfferEligibility
            subInfo["isTrialEligible"] = boolOrNull(for: introOfferEligibility)
            productMaps[index]["subscription"] = subInfo
        }
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() {
        updateListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                guard let transaction = try? self.checkVerification(result) else { continue }
                let product = await self.loadProduct(for: transaction.productID)
                let entry = await self.entitlementMap(for: transaction, product: product)
                await transaction.finish()
                DispatchQueue.main.async {
                    self.transactionSink?(entry)
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKit2Error.verificationFailed
        case .verified(let value):
            return value
        }
    }

    private func purchaseResultMap(for transaction: Transaction, product: Product) async -> [String: Any] {
        var entry = await transactionMap(for: transaction, product: product)
        entry["status"] = "success"
        return entry
    }

    private func entitlementMap(for transaction: Transaction, product: Product?) async -> [String: Any] {
        var entry = await transactionMap(for: transaction, product: product)
        entry["isActive"] = isActive(transaction)
        return entry
    }

    private func transactionMap(for transaction: Transaction, product: Product?) async -> [String: Any] {
        let introOffer = introOfferContext(for: transaction, product: product)
        var entry: [String: Any] = [
            "productId": transaction.productID,
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "purchaseDate": millisecondsSinceEpoch(transaction.purchaseDate),
            "ownershipType": ownershipTypeName(transaction.ownershipType),
            "isIntroOffer": introOffer.isIntroOffer,
            "isTrial": introOffer.offerType == "freeTrial",
            "willAutoRenew": await getWillAutoRenew(for: transaction),
        ]

        if let product {
            entry["productType"] = productTypeName(product.type)
        }

        if let expirationDate = transaction.expirationDate {
            entry["expirationDate"] = millisecondsSinceEpoch(expirationDate)
        }

        if let revocationDate = transaction.revocationDate {
            entry["revocationDate"] = millisecondsSinceEpoch(revocationDate)
        }

        if let introOfferType = introOffer.offerType {
            entry["introOfferType"] = introOfferType
        }

        return entry
    }

    private func isActive(_ transaction: Transaction, now: Date = Date()) -> Bool {
        if transaction.revocationDate != nil {
            return false
        }

        guard let expirationDate = transaction.expirationDate else {
            return true
        }

        return expirationDate > now
    }

    private func isIntroductoryOffer(_ transaction: Transaction) -> Bool {
        if #available(iOS 17.2, *) {
            return transaction.offer?.type == .introductory
        }

        return transaction.offerType == .introductory
    }

    private func introOfferContext(
        for transaction: Transaction,
        product: Product?
    ) -> (isIntroOffer: Bool, offerType: String?) {
        guard isIntroductoryOffer(transaction) else {
            return (false, nil)
        }

        guard let introOffer = product?.subscription?.introductoryOffer else {
            return (true, nil)
        }

        return (true, offerTypeName(introOffer.paymentMode))
    }

    private func getWillAutoRenew(for transaction: Transaction) async -> Bool {
        guard let groupID = transaction.subscriptionGroupID else {
            return false
        }

        guard let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else {
            return false
        }

        for status in statuses {
            guard let renewalInfo = try? checkVerification(status.renewalInfo),
                  let statusTransaction = try? checkVerification(status.transaction) else {
                continue
            }

            let matchesOriginalTransaction = statusTransaction.originalID == transaction.originalID
            let matchesCurrentProduct = renewalInfo.currentProductID == transaction.productID
            let matchesStatusProduct = statusTransaction.productID == transaction.productID

            if matchesOriginalTransaction || matchesCurrentProduct || matchesStatusProduct {
                return renewalInfo.willAutoRenew
            }
        }

        return false
    }

    private func mapProduct(_ product: Product) -> [String: Any] {
        var map: [String: Any] = [
            "id": product.id,
            "displayName": product.displayName,
            "description": product.description,
            "price": NSDecimalNumber(decimal: product.price).doubleValue,
            "currencyCode": product.priceFormatStyle.currencyCode,
            "type": productTypeName(product.type),
        ]

        switch product.type {
        case .autoRenewable, .nonRenewable:
            var subInfo: [String: Any] = [
                "isAutoRenewable": product.type == .autoRenewable,
                "introOfferEligibility": "unknown",
                "isTrialEligible": NSNull(),
            ]

            if let period = subscriptionPeriodMap(product.subscription?.subscriptionPeriod) {
                subInfo["period"] = period
            }

            if let intro = product.subscription?.introductoryOffer {
                var introOfferMap: [String: Any] = [
                    "price": NSDecimalNumber(decimal: intro.price).doubleValue,
                    "currencyCode": product.priceFormatStyle.currencyCode,
                    "offerType": offerTypeName(intro.paymentMode),
                ]

                if let period = subscriptionPeriodMap(intro.period) {
                    introOfferMap["period"] = period
                }

                subInfo["introOffer"] = introOfferMap

                if intro.paymentMode == .freeTrial {
                    subInfo["trial"] = introOfferMap
                }
            }

            map["subscription"] = subInfo

        case .consumable, .nonConsumable:
            break
        default:
            break
        }

        return map
    }

    private func loadProduct(for productID: String) async -> Product? {
        let products = try? await Product.products(for: [productID])
        return products?.first
    }

    private func loadProductsByID(_ identifiers: Set<String>) async -> [String: Product] {
        guard !identifiers.isEmpty,
              let products = try? await Product.products(for: identifiers) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    private func productTypeName(_ type: Product.ProductType) -> String {
        switch type {
        case .autoRenewable, .nonRenewable:
            return "subscription"
        case .consumable:
            return "consumable"
        case .nonConsumable:
            return "nonConsumable"
        default:
            return "nonConsumable"
        }
    }

    private func ownershipTypeName(_ ownershipType: Transaction.OwnershipType) -> String {
        switch ownershipType {
        case .purchased:
            return "purchased"
        case .familyShared:
            return "familyShared"
        default:
            return "purchased"
        }
    }

    private func offerTypeName(_ paymentMode: Product.SubscriptionOffer.PaymentMode) -> String {
        switch paymentMode {
        case .freeTrial:
            return "freeTrial"
        case .payAsYouGo:
            return "payAsYouGo"
        case .payUpFront:
            return "payUpFront"
        default:
            return "freeTrial"
        }
    }

    private func subscriptionPeriodMap(_ period: Product.SubscriptionPeriod?) -> [String: Any]? {
        guard let period else {
            return nil
        }

        return [
            "value": period.value,
            "unit": subscriptionPeriodUnitName(period.unit),
        ]
    }

    private func subscriptionPeriodUnitName(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        @unknown default:
            return "day"
        }
    }

    private func millisecondsSinceEpoch(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }

    private func boolOrNull(for eligibility: String) -> Any {
        switch eligibility {
        case "eligible":
            return true
        case "ineligible":
            return false
        default:
            return NSNull()
        }
    }
}

enum StoreKit2Error: Error, LocalizedError {
    case productNotFound
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .verificationFailed:
            return "Transaction verification failed"
        case .unknown:
            return "Unknown StoreKit error"
        }
    }
}
