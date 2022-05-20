/*
 Copyright © 2021 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Abstract:
The Store is responsible for requesting products from the App Store and starting purchases; other parts of
    the app query the store to learn what products have been purchased.
*/

import AppReceiptValidator
import Foundation
import StoreKit

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

public enum SubscriptionTier: Int, Comparable {
    case none = 0
    case standard = 1

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class Store: ObservableObject {

    @Published private(set) var subscriptions: [Product]

    @Published private(set) var purchasedIdentifiers = Set<String>() {
        didSet {
            isSubscribed = purchasedIdentifiers.contains(Store.standardSubscriptionProductId)
        }
    }

    @Published private(set) var isSubscribed: Bool = false

    @Published private(set) var isPurchasedBeforeFree: Bool = false

    var purchaseReceipt: Receipt? = nil

    var canMakePayments: Bool {
        AppStore.canMakePayments
    }
    var updateListenerTask: Task<Void, Error>? = nil

    static let standardSubscriptionProductId = "thebaselab.codeapp.standard"

    private static let subscriptionTier: [String: SubscriptionTier] = [
        standardSubscriptionProductId: .standard
    ]

    init() {
        //Initialize empty products then do a product request asynchronously to fill them in.
        subscriptions = []

        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            //Initialize the store by starting a product request.
            await requestProducts()
            await checkSubscriptionStatus()
        }

        let receiptValidator = AppReceiptValidator()
        let installedReceipt = try? receiptValidator.parseReceipt(origin: .installedInMainBundle)
        purchaseReceipt = installedReceipt

        if let originalAppVersion = installedReceipt?.originalAppVersion {
            print("originalAppVersion", originalAppVersion)

            isPurchasedBeforeFree = originalAppVersion < "83"
        }
        print("isPurchasedBeforeFree", isPurchasedBeforeFree)
    }

    deinit {
        updateListenerTask?.cancel()
    }

    @MainActor
    func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Store.standardSubscriptionProductId {
                    self.isSubscribed = true
                }
            }
        }
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    //Deliver content to the user.
                    await self.updatePurchasedIdentifiers(transaction)

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a receipt it can read but it failed verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }

    @MainActor
    func requestProducts() async {
        do {
            //Request products from the App Store using the identifiers defined in the Products.plist file.
            let storeProducts = try await Product.products(for: [
                Store.standardSubscriptionProductId
            ])

            var newSubscriptions: [Product] = []

            //Filter the products into different categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .autoRenewable:
                    print("Got Subscription")
                    print(product.displayName)
                    print(product.displayPrice)
                    newSubscriptions.append(product)
                default:
                    //Ignore this product.
                    print("Unknown product")
                }
            }

            //Sort each product category by price, lowest to highest, to update the store.
            subscriptions = sortByPrice(newSubscriptions)
        } catch {
            print("Failed product request: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        //Begin a purchase.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            //Deliver content to the user.
            await updatePurchasedIdentifiers(transaction)

            //Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    func isPurchased(_ productIdentifier: String) async throws -> Bool {
        //Get the most recent transaction receipt for this `productIdentifier`.
        guard let result = await Transaction.latest(for: productIdentifier) else {
            //If there is no latest transaction, the product has not been purchased.
            return false
        }

        let transaction = try checkVerified(result)

        //Ignore revoked transactions, they're no longer purchased.

        //For subscriptions, a user can upgrade in the middle of their subscription period. The lower service
        //tier will then have the `isUpgraded` flag set and there will be a new transaction for the higher service
        //tier. Ignore the lower service tier transactions which have been upgraded.
        return transaction.revocationDate == nil && !transaction.isUpgraded
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check if the transaction passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit has parsed the JWS but failed verification. Don't deliver content to the user.
            throw StoreError.failedVerification
        case .verified(let safe):
            //If the transaction is verified, unwrap and return it.
            return safe
        }
    }

    @MainActor
    func updatePurchasedIdentifiers(_ transaction: Transaction) async {
        if transaction.revocationDate == nil {
            //If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
            print("Inserting", transaction.productID)
            purchasedIdentifiers.insert(transaction.productID)
            if transaction.productID == Store.standardSubscriptionProductId {
                isSubscribed = true
            }
        } else {
            //If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
            purchasedIdentifiers.remove(transaction.productID)
        }
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }

    func tier(for productId: String) -> SubscriptionTier {
        switch productId {
        case Store.standardSubscriptionProductId:
            return .standard
        default:
            return .none
        }
    }

    @MainActor
    func beginRefundProcess() {
        guard
            let keyWindow = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .map({ $0 as? UIWindowScene })
                .compactMap({ $0 })
                .first?.windows
                .filter({ $0.isKeyWindow }).first,
            let scene = keyWindow.windowScene
        else { return }

        Task {
            guard
                case .verified(let transaction) = await Transaction.latest(
                    for: Store.standardSubscriptionProductId)
            else { return }

            do {
                let status = try await transaction.beginRefundRequest(in: scene)

                switch status {
                case .userCancelled:
                    break
                case .success:
                    // Maybe show something in the UI indicating that the refund is processing
                    //                    setRefundingStatus(on: productID)
                    print("Processing refund")
                @unknown default:
                    assertionFailure("Unexpected status")
                    break
                }
            } catch {
                print("Refund request failed to start: \(error)")
            }
        }
    }
}
