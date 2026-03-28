import StoreKit
import StoreKitTest
import XCTest

@testable import ios_storekit2

@available(iOS 15.0, *)
final class RunnerTests: XCTestCase {
  private enum ProductID {
    static let monthly = "com.example.monthly"
    static let yearly = "com.example.yearly"
    static let lifetime = "com.example.lifetime"
  }

  private var session: SKTestSession!
  private var manager: StoreKit2Manager!

  override func setUpWithError() throws {
    try super.setUpWithError()

    let bundle = Bundle(for: Self.self)
    let configurationURL = try XCTUnwrap(
      bundle.url(forResource: "Configuration", withExtension: "storekit"),
      "Configuration.storekit must be added to the RunnerTests bundle"
    )

    session = try SKTestSession(contentsOf: configurationURL)
    session.resetToDefaultState()
    session.clearTransactions()
    session.disableDialogs = true
    session.locale = Locale(identifier: "en_US")
    session.storefront = "USA"

    if #available(iOS 16.4, *) {
      session.timeRate = .oneRenewalEveryTenSeconds
    } else if #available(iOS 15.2, *) {
      session.timeRate = .monthlyRenewalEveryThirtySeconds
    }

    manager = StoreKit2Manager()
  }

  override func tearDownWithError() throws {
    manager?.setTransactionSink(nil)
    session?.resetToDefaultState()
    session?.clearTransactions()
    manager = nil
    session = nil
    try super.tearDownWithError()
  }

  func testFetchProductsMapsStoreKitMetadata() async throws {
    let storeProducts = try await Product.products(for: [
      ProductID.monthly,
      ProductID.yearly,
      ProductID.lifetime,
    ])
    XCTAssertEqual(storeProducts.count, 3)

    var mappedProducts = manager.fetchProducts(products: storeProducts)
    await manager.updateTrialEligibility(&mappedProducts, products: storeProducts)

    let productsByID: [String: [String: Any]] = Dictionary(
      uniqueKeysWithValues: mappedProducts.compactMap { entry -> (String, [String: Any])? in
        guard let id = entry["id"] as? String else {
          return nil
        }
        return (id, entry)
      }
    )

    let monthly = try XCTUnwrap(productsByID[ProductID.monthly])
    XCTAssertEqual(monthly["type"] as? String, "subscription")
    let monthlySubscription = try XCTUnwrap(monthly["subscription"] as? [String: Any])
    let monthlyPeriod = try XCTUnwrap(monthlySubscription["period"] as? [String: Any])
    XCTAssertEqual(monthlyPeriod["value"] as? Int, 1)
    XCTAssertEqual(monthlyPeriod["unit"] as? String, "month")
    XCTAssertEqual(monthlySubscription["isAutoRenewable"] as? Bool, true)
    let monthlyIntroOffer = try XCTUnwrap(monthlySubscription["introOffer"] as? [String: Any])
    let monthlyTrial = try XCTUnwrap(monthlySubscription["trial"] as? [String: Any])
    let monthlyTrialPeriod = try XCTUnwrap(monthlyIntroOffer["period"] as? [String: Any])
    XCTAssertEqual(monthlyIntroOffer["offerType"] as? String, "freeTrial")
    XCTAssertEqual(monthlyTrialPeriod["value"] as? Int, 1)
    XCTAssertEqual(monthlyTrialPeriod["unit"] as? String, "week")
    XCTAssertEqual(monthlyTrial["offerType"] as? String, "freeTrial")

    if #available(iOS 16.0, *) {
      XCTAssertEqual(monthlySubscription["introOfferEligibility"] as? String, "eligible")
      XCTAssertEqual(monthlySubscription["isTrialEligible"] as? Bool, true)
    } else {
      XCTAssertEqual(monthlySubscription["introOfferEligibility"] as? String, "unknown")
      XCTAssertTrue(monthlySubscription["isTrialEligible"] is NSNull)
    }

    let yearly = try XCTUnwrap(productsByID[ProductID.yearly])
    let yearlySubscription = try XCTUnwrap(yearly["subscription"] as? [String: Any])
    let yearlyPeriod = try XCTUnwrap(yearlySubscription["period"] as? [String: Any])
    XCTAssertEqual(yearlyPeriod["value"] as? Int, 1)
    XCTAssertEqual(yearlyPeriod["unit"] as? String, "year")
    XCTAssertNil(yearlySubscription["introOffer"])
    XCTAssertNil(yearlySubscription["trial"])

    let lifetime = try XCTUnwrap(productsByID[ProductID.lifetime])
    XCTAssertEqual(lifetime["type"] as? String, "nonConsumable")
    XCTAssertNil(lifetime["subscription"])
  }

  func testPurchaseNonConsumableCreatesEntitlement() async throws {
    let purchase = try await manager.purchase(productID: ProductID.lifetime)
    XCTAssertEqual(purchase["status"] as? String, "success")
    XCTAssertEqual(purchase["productId"] as? String, ProductID.lifetime)
    XCTAssertEqual(purchase["productType"] as? String, "nonConsumable")
    XCTAssertNotNil(purchase["transactionId"])
    XCTAssertNotNil(purchase["originalTransactionId"])
    XCTAssertNotNil(purchase["purchaseDate"])
    XCTAssertEqual(purchase["ownershipType"] as? String, "purchased")
    XCTAssertEqual(purchase["isIntroOffer"] as? Bool, false)

    let entitlement = try await currentEntitlement(for: ProductID.lifetime)
    XCTAssertEqual(entitlement["productId"] as? String, ProductID.lifetime)
    XCTAssertEqual(entitlement["productType"] as? String, "nonConsumable")
    XCTAssertEqual(entitlement["isActive"] as? Bool, true)
    XCTAssertEqual(entitlement["willAutoRenew"] as? Bool, false)
    XCTAssertNotNil(entitlement["transactionId"])
    XCTAssertNotNil(entitlement["purchaseDate"])
    XCTAssertNil(entitlement["expirationDate"])
  }

  func testAskToBuyApprovalPublishesTransactionUpdate() async throws {
    session.askToBuyEnabled = true

    let approved = expectation(description: "Approved ask-to-buy transaction")
    manager.setTransactionSink { entry in
      if entry["productId"] as? String == ProductID.monthly,
         entry["isActive"] as? Bool == true {
        approved.fulfill()
      }
    }

    let purchase = try await manager.purchase(productID: ProductID.monthly)
    XCTAssertEqual(purchase["status"] as? String, "pending")

    let pendingTransaction = try latestTransaction(for: ProductID.monthly)
    XCTAssertTrue(pendingTransaction.pendingAskToBuyConfirmation)

    try session.approveAskToBuyTransaction(identifier: pendingTransaction.identifier)
    await fulfillment(of: [approved], timeout: 5.0)

    let foundEntitlement = await findEntitlement(for: ProductID.monthly)
    XCTAssertNotNil(foundEntitlement)
  }

  func testAskToBuyDeclineDoesNotGrantEntitlement() async throws {
    session.askToBuyEnabled = true

    let purchase = try await manager.purchase(productID: ProductID.yearly)
    XCTAssertEqual(purchase["status"] as? String, "pending")

    let pendingTransaction = try latestTransaction(for: ProductID.yearly)
    XCTAssertTrue(pendingTransaction.pendingAskToBuyConfirmation)

    try session.declineAskToBuyTransaction(identifier: pendingTransaction.identifier)

    let declined = await waitUntil {
      await self.findEntitlement(for: ProductID.yearly) == nil
    }
    XCTAssertTrue(declined)
  }

  func testRefundRevokesNonConsumable() async throws {
    _ = try await manager.purchase(productID: ProductID.lifetime)

    let refunded = expectation(description: "Refund update received")
    manager.setTransactionSink { entry in
      if entry["productId"] as? String == ProductID.lifetime,
         entry["isActive"] as? Bool == false {
        refunded.fulfill()
      }
    }

    let transaction = try latestTransaction(for: ProductID.lifetime)
    try session.refundTransaction(identifier: transaction.identifier)
    await fulfillment(of: [refunded], timeout: 5.0)

    let entitlementRemoved = await waitUntil {
      await self.findEntitlement(for: ProductID.lifetime) == nil
    }
    XCTAssertTrue(entitlementRemoved)
  }

  func testExpireSubscriptionRemovesEntitlement() async throws {
    _ = try await manager.purchase(productID: ProductID.monthly)
    let activeEntitlement = await findEntitlement(for: ProductID.monthly)
    XCTAssertNotNil(activeEntitlement)

    try session.expireSubscription(productIdentifier: ProductID.monthly)

    let expired = await waitUntil {
      await self.findEntitlement(for: ProductID.monthly) == nil
    }
    XCTAssertTrue(expired)
  }

  func testForceRenewalKeepsSubscriptionActive() async throws {
    _ = try await manager.purchase(productID: ProductID.monthly)

    let renewed = expectation(description: "Renewal update received")
    manager.setTransactionSink { entry in
      if entry["productId"] as? String == ProductID.monthly,
         entry["isActive"] as? Bool == true,
         entry["willAutoRenew"] as? Bool == true {
        renewed.fulfill()
      }
    }

    try session.forceRenewalOfSubscription(productIdentifier: ProductID.monthly)
    await fulfillment(of: [renewed], timeout: 5.0)

    let entitlement = try await currentEntitlement(for: ProductID.monthly)
    XCTAssertEqual(entitlement["isActive"] as? Bool, true)
    XCTAssertEqual(entitlement["willAutoRenew"] as? Bool, true)
  }

  func testPurchaseSubscriptionCreatesEntitlementWithExpiration() async throws {
    let purchase = try await manager.purchase(productID: ProductID.monthly)
    XCTAssertEqual(purchase["status"] as? String, "success")
    XCTAssertEqual(purchase["productId"] as? String, ProductID.monthly)
    XCTAssertEqual(purchase["productType"] as? String, "subscription")
    XCTAssertEqual(purchase["isIntroOffer"] as? Bool, true)
    XCTAssertEqual(purchase["introOfferType"] as? String, "freeTrial")
    XCTAssertEqual(purchase["isTrial"] as? Bool, true)

    let entitlement = try await currentEntitlement(for: ProductID.monthly)
    XCTAssertEqual(entitlement["isActive"] as? Bool, true)
    XCTAssertEqual(entitlement["productType"] as? String, "subscription")
    XCTAssertEqual(entitlement["willAutoRenew"] as? Bool, true)
    XCTAssertNotNil(entitlement["expirationDate"], "Subscription must have an expiration date")
  }

  func testSubscriptionPurchaseDetectsTrialPeriod() async throws {
    // monthly has a 7-day free trial configured
    let purchase = try await manager.purchase(productID: ProductID.monthly)
    XCTAssertEqual(purchase["status"] as? String, "success")
    XCTAssertEqual(purchase["isIntroOffer"] as? Bool, true)
    XCTAssertEqual(purchase["introOfferType"] as? String, "freeTrial")
    XCTAssertEqual(purchase["isTrial"] as? Bool, true)

    let entitlement = try await currentEntitlement(for: ProductID.monthly)
    XCTAssertEqual(entitlement["isIntroOffer"] as? Bool, true)
    XCTAssertEqual(entitlement["introOfferType"] as? String, "freeTrial")
    XCTAssertEqual(entitlement["isTrial"] as? Bool, true, "First purchase of monthly should be on trial")
  }

  func testTrialEligibilityBecomesFalseAfterPurchase() async throws {
    // Before purchase — should be eligible
    let productsBefore = try await Product.products(for: [ProductID.monthly])
    var mapsBefore = manager.fetchProducts(products: productsBefore)
    await manager.updateTrialEligibility(&mapsBefore, products: productsBefore)
    let subBefore = try XCTUnwrap(mapsBefore.first?["subscription"] as? [String: Any])

    if #available(iOS 16.0, *) {
      XCTAssertEqual(subBefore["introOfferEligibility"] as? String, "eligible")
      XCTAssertEqual(subBefore["isTrialEligible"] as? Bool, true, "Should be trial eligible before first purchase")
    } else {
      XCTAssertEqual(subBefore["introOfferEligibility"] as? String, "unknown")
      XCTAssertTrue(subBefore["isTrialEligible"] is NSNull)
    }

    // Purchase uses the trial
    _ = try await manager.purchase(productID: ProductID.monthly)

    // After purchase — should no longer be eligible
    let productsAfter = try await Product.products(for: [ProductID.monthly])
    var mapsAfter = manager.fetchProducts(products: productsAfter)
    await manager.updateTrialEligibility(&mapsAfter, products: productsAfter)
    let subAfter = try XCTUnwrap(mapsAfter.first?["subscription"] as? [String: Any])

    if #available(iOS 16.0, *) {
      XCTAssertEqual(subAfter["introOfferEligibility"] as? String, "ineligible")
      XCTAssertEqual(subAfter["isTrialEligible"] as? Bool, false, "Should not be trial eligible after purchase")
    } else {
      XCTAssertEqual(subAfter["introOfferEligibility"] as? String, "unknown")
      XCTAssertTrue(subAfter["isTrialEligible"] is NSNull)
    }
  }

  func testPurchaseNonExistentProductThrows() async throws {
    do {
      _ = try await manager.purchase(productID: "com.example.nonexistent")
      XCTFail("Expected purchase of nonexistent product to throw")
    } catch {
      XCTAssertTrue(error is StoreKit2Error)
      XCTAssertEqual(error.localizedDescription, "Product not found")
    }
  }

  func testSubscriptionEntitlementWillAutoRenewViaGetEntitlements() async throws {
    _ = try await manager.purchase(productID: ProductID.monthly)

    let entitlement = try await currentEntitlement(for: ProductID.monthly)
    XCTAssertEqual(entitlement["isActive"] as? Bool, true)
    XCTAssertEqual(
      entitlement["willAutoRenew"] as? Bool, true,
      "Active subscription should report willAutoRenew=true via getEntitlements"
    )
  }

  func testYearlySubscriptionHasNoTrialOnPurchase() async throws {
    // yearly has no introductory offer configured
    _ = try await manager.purchase(productID: ProductID.yearly)

    let entitlement = try await currentEntitlement(for: ProductID.yearly)
    XCTAssertEqual(entitlement["isIntroOffer"] as? Bool, false)
    XCTAssertNil(entitlement["introOfferType"])
    XCTAssertEqual(entitlement["isTrial"] as? Bool, false, "Yearly has no trial configured")
  }

  func testRestorePurchasesDoesNotThrow() async throws {
    _ = try await manager.purchase(productID: ProductID.lifetime)
    try await manager.restorePurchases()

    let restoredEntitlement = await findEntitlement(for: ProductID.lifetime)
    XCTAssertNotNil(restoredEntitlement)
  }

  private func latestTransaction(for productID: String) throws -> SKTestTransaction {
    let transaction = session
      .allTransactions()
      .last(where: { $0.productIdentifier == productID })

    return try XCTUnwrap(transaction)
  }

  private func currentEntitlement(for productID: String) async throws -> [String: Any] {
    let entitlement = await findEntitlement(for: productID)
    return try XCTUnwrap(entitlement)
  }

  private func findEntitlement(for productID: String) async -> [String: Any]? {
    let entitlements = await manager.currentEntitlements()
    return entitlements.first { $0["productId"] as? String == productID }
  }

  private func waitUntil(
    timeout: TimeInterval = 5.0,
    pollIntervalNanoseconds: UInt64 = 200_000_000,
    condition: @escaping () async -> Bool
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      if await condition() {
        return true
      }
      try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    return await condition()
  }
}
