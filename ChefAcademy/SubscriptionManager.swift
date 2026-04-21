//
//  SubscriptionManager.swift
//  ChefAcademy
//
//  StoreKit 2 coordinator for the Pip Plus subscription tier.
//
//  TEACHING MOMENT: StoreKit 2 (iOS 15+) vs StoreKit 1
//  ---------------------------------------------------
//  StoreKit 2 is a ground-up rewrite using Swift concurrency.
//  Old StoreKit 1: delegate callbacks, manual receipt parsing, transactions via notifications.
//  New StoreKit 2: async/await, type-safe `Product` + `Transaction`, JWS-signed receipts
//  verified by Apple automatically. Half the code, none of the footguns.
//
//  THIS FILE'S JOB:
//  - Fetch the Pip Chat subscription product from App Store Connect
//  - Listen for transaction updates (new purchases, renewals, refunds, family-share grants)
//  - Expose a single published `isPremium` flag the rest of the app reads
//  - Expose `isInTrial` so PipAIService can enforce the 5 Q/day trial cap
//  - Persist last-known state so launches show correct UI before StoreKit refreshes
//

import Foundation
import StoreKit
import Combine

// MARK: - Product IDs
//
// These MUST match the Product IDs configured in App Store Connect.
// Changing them here without updating ASC breaks purchase flow.

enum PipProductID {
    static let pipChatMonthly = "com.GraphicElegance.ChefAcademy.pipchat.monthly"
}

// MARK: - Subscription Manager

@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published State

    /// True when the user has an active Pip Chat subscription (paid OR in trial).
    /// AskPipView reads this to unlock the full Claude chat.
    @Published private(set) var isPremium: Bool = false

    /// True when the active subscription is in the free-trial window.
    /// PipAIService reads this to apply the 5 Q/day trial cap.
    @Published private(set) var isInTrial: Bool = false

    /// Fetched products, indexed by product ID for lookup.
    @Published private(set) var products: [String: Product] = [:]

    /// Last error from a purchase attempt (e.g., user cancelled, network failure).
    @Published private(set) var purchaseError: String?

    /// Subscription period end (for display in ParentDashboard).
    @Published private(set) var expirationDate: Date?

    // MARK: - DEBUG Override
    //
    // Flip in ParentDashboard during development to test premium paths
    // without going through a sandbox purchase. NEVER reachable in Release builds.

    #if DEBUG
    @Published var debugForcePremium: Bool = false {
        didSet { recomputePremium() }
    }
    #endif

    // MARK: - Persistence

    private let lastKnownPremiumKey = "com.chefacademy.subscription.isPremium"
    private let lastKnownTrialKey = "com.chefacademy.subscription.isInTrial"

    // MARK: - Private State

    private var transactionUpdatesTask: Task<Void, Never>?
    private var storeKitIsPremium: Bool = false   // truth from StoreKit

    // MARK: - Init

    init() {
        // Restore last-known state so UI renders correctly before StoreKit refreshes.
        // StoreKit 2 can take 1-3s on cold launch; without this the paywall would flash.
        let cachedPremium = UserDefaults.standard.bool(forKey: lastKnownPremiumKey)
        let cachedTrial = UserDefaults.standard.bool(forKey: lastKnownTrialKey)
        self.storeKitIsPremium = cachedPremium
        self.isInTrial = cachedTrial
        recomputePremium()

        // Listen for transaction updates (renewals, refunds, family-share grants).
        // This must run for the entire app lifetime.
        transactionUpdatesTask = Task.detached { [weak self] in
            for await verificationResult in Transaction.updates {
                await self?.handle(verificationResult)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - Public API

    /// Fetch products from App Store Connect. Call once at app launch.
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [PipProductID.pipChatMonthly])
            print("[SubscriptionManager] loadProducts -> \(storeProducts.count) product(s): \(storeProducts.map(\.id))")
            var map: [String: Product] = [:]
            for product in storeProducts { map[product.id] = product }
            self.products = map
            if storeProducts.isEmpty {
                purchaseError = "No products returned from App Store. Check ASC setup or wait for propagation (can take 15-60 min)."
            }
            await refreshSubscriptionStatus()
        } catch {
            print("[SubscriptionManager] loadProducts FAILED: \(error)")
            purchaseError = "Couldn't load subscription info: \(error.localizedDescription)"
        }
    }

    /// Refresh subscription status by checking current entitlements.
    /// Called on launch and after any purchase/restore.
    func refreshSubscriptionStatus() async {
        var foundPremium = false
        var foundTrial = false
        var foundExpiration: Date?

        // `Transaction.currentEntitlements` is the source of truth.
        // It includes paid subs, trials, family-share grants, and introductory offers.
        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else { continue }
            guard transaction.productID == PipProductID.pipChatMonthly else { continue }
            guard transaction.revocationDate == nil else { continue }   // refunded / revoked

            foundPremium = true
            foundExpiration = transaction.expirationDate

            // Trial detection — StoreKit 2 exposes `offerType` on the transaction.
            // `.introductory` means the user is in the free-trial period.
            if transaction.offer?.type == .introductory {
                foundTrial = true
            }
        }

        self.storeKitIsPremium = foundPremium
        self.isInTrial = foundTrial
        self.expirationDate = foundExpiration
        recomputePremium()
        persistState()
    }

    /// Attempt to purchase the Pip Chat subscription.
    /// Returns true on success, false on cancel/failure.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    purchaseError = "Purchase could not be verified"
                    return false
                }
                await transaction.finish()
                await refreshSubscriptionStatus()
                return true

            case .userCancelled:
                return false

            case .pending:
                // Parent approval pending (Ask to Buy / Family Sharing)
                purchaseError = "Waiting for approval"
                return false

            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    /// Restore previous purchases — required by Apple for all subscription apps.
    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            purchaseError = "Couldn't restore: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Helpers

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshSubscriptionStatus()
    }

    private func recomputePremium() {
        #if DEBUG
        isPremium = storeKitIsPremium || debugForcePremium
        #else
        isPremium = storeKitIsPremium
        #endif
    }

    private func persistState() {
        UserDefaults.standard.set(storeKitIsPremium, forKey: lastKnownPremiumKey)
        UserDefaults.standard.set(isInTrial, forKey: lastKnownTrialKey)
    }
}
