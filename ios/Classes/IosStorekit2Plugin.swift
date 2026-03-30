import Flutter
import StoreKit
import UIKit

private func serializeFlutterErrorValue(_ value: Any) -> Any {
    switch value {
    case let number as NSNumber:
        return number
    case let string as NSString:
        return String(string)
    case let url as URL:
        return url.absoluteString
    case let date as Date:
        return Int(date.timeIntervalSince1970 * 1000)
    case let error as NSError:
        return makeFlutterErrorDetails(error: error)
    case let array as [Any]:
        return array.map(serializeFlutterErrorValue)
    case let dictionary as [AnyHashable: Any]:
        return Dictionary(uniqueKeysWithValues: dictionary.map { key, nestedValue in
            (String(describing: key), serializeFlutterErrorValue(nestedValue))
        })
    case is NSNull:
        return NSNull()
    default:
        return String(describing: value)
    }
}

func makeFlutterErrorDetails(error: NSError) -> [String: Any] {
    var details: [String: Any] = [
        "nativeErrorDomain": error.domain,
        "nativeErrorCode": error.code,
        "nativeLocalizedDescription": error.localizedDescription,
    ]

    if let failureReason = error.localizedFailureReason {
        details["nativeLocalizedFailureReason"] = failureReason
    }

    if let recoverySuggestion = error.localizedRecoverySuggestion {
        details["nativeLocalizedRecoverySuggestion"] = recoverySuggestion
    }

    if let helpAnchor = error.helpAnchor {
        details["nativeHelpAnchor"] = helpAnchor
    }

    if !error.userInfo.isEmpty {
        details["nativeErrorUserInfo"] = serializeFlutterErrorValue(error.userInfo)
    }

    return details
}

func makeFlutterError(code: String, error: Error) -> FlutterError {
    let nativeError = error as NSError
    var details = makeFlutterErrorDetails(error: nativeError)

    if #available(iOS 15.0, *), case StoreKit.StoreKitError.networkError(let urlError) = error {
        details["underlyingURLError"] = makeFlutterErrorDetails(error: urlError as NSError)
    }

    return FlutterError(
        code: code,
        message: nativeError.localizedDescription,
        details: details
    )
}

public class IosStorekit2Plugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var storeManager: Any?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "ios_storekit2",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "ios_storekit2/transactions",
            binaryMessenger: registrar.messenger()
        )

        let instance = IosStorekit2Plugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        if #available(iOS 15.0, *) {
            let manager = StoreKit2Manager()
            instance.storeManager = manager
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        if #available(iOS 15.0, *), let manager = storeManager as? StoreKit2Manager {
            manager.setTransactionSink { [weak self] entry in
                DispatchQueue.main.async {
                    self?.eventSink?(entry)
                }
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        if #available(iOS 15.0, *), let manager = storeManager as? StoreKit2Manager {
            manager.setTransactionSink(nil)
        }
        return nil
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 15.0, *), let manager = storeManager as? StoreKit2Manager else {
            result(FlutterError(code: "UNAVAILABLE", message: "StoreKit 2 requires iOS 15.0+", details: nil))
            return
        }

        switch call.method {
        case "getProducts":
            handleGetProducts(call: call, result: result, manager: manager)
        case "purchase":
            handlePurchase(call: call, result: result, manager: manager)
        case "getEntitlements":
            handleGetEntitlements(result: result, manager: manager)
        case "restorePurchases":
            handleRestorePurchases(result: result, manager: manager)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers

    @available(iOS 15.0, *)
    private func handleGetProducts(call: FlutterMethodCall, result: @escaping FlutterResult, manager: StoreKit2Manager) {
        guard let args = call.arguments as? [String: Any],
              let identifiers = args["identifiers"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing identifiers", details: nil))
            return
        }

        Task {
            do {
                let products = try await Product.products(for: Set(identifiers))
                var maps = manager.fetchProducts(products: products)
                await manager.updateTrialEligibility(&maps, products: products)
                DispatchQueue.main.async {
                    result(maps)
                }
            } catch {
                DispatchQueue.main.async {
                    result(makeFlutterError(code: "FETCH_ERROR", error: error))
                }
            }
        }
    }

    @available(iOS 15.0, *)
    private func handlePurchase(call: FlutterMethodCall, result: @escaping FlutterResult, manager: StoreKit2Manager) {
        guard let args = call.arguments as? [String: Any],
              let productId = args["productId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing productId", details: nil))
            return
        }

        Task {
            do {
                let purchaseResult = try await manager.purchase(productID: productId)
                DispatchQueue.main.async {
                    result(purchaseResult)
                }
            } catch {
                DispatchQueue.main.async {
                    result(makeFlutterError(code: "PURCHASE_ERROR", error: error))
                }
            }
        }
    }

    @available(iOS 15.0, *)
    private func handleGetEntitlements(result: @escaping FlutterResult, manager: StoreKit2Manager) {
        Task {
            let entitlements = await manager.currentEntitlements()
            DispatchQueue.main.async {
                result(entitlements)
            }
        }
    }

    @available(iOS 15.0, *)
    private func handleRestorePurchases(result: @escaping FlutterResult, manager: StoreKit2Manager) {
        Task {
            do {
                try await manager.restorePurchases()
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(makeFlutterError(code: "RESTORE_ERROR", error: error))
                }
            }
        }
    }
}
