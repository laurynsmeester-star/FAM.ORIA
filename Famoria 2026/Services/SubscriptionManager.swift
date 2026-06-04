//
//  SubscriptionManager.swift
//  Famoria 2026
//
//  StoreKit 2 layer for the Famoria Plus subscription. Loads products,
//  runs purchases through StoreKit, listens to the `Transaction.updates`
//  stream for renewals/cancellations/revocations, and exposes a small
//  observable surface the rest of the app reads via `@EnvironmentObject`.
//
//  Family-level sync is handled separately by `SubscriptionSyncService`,
//  which subscribes to `currentStatus` changes and writes them onto the
//  family document so every member inherits the entitlement.
//

import Foundation
import os
import Combine
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published surface

    /// Products fetched from StoreKit, keyed by the FamoriaProduct id so
    /// the paywall can look up "monthly" and "annual" in O(1).
    @Published private(set) var products: [String: Product] = [:]

    /// The combined status across all our subscriptions. Updated whenever
    /// a transaction arrives or the user re-checks `currentEntitlements`.
    @Published private(set) var currentStatus: SubscriptionStatus = .unknown

    /// `Product.SubscriptionInfo.RenewalInfo` exposes whether the user is
    /// inside their intro free trial; we surface that here so the UI can
    /// say "Free trial — renews on X".
    @Published private(set) var inTrial: Bool = false

    /// The `expiresDate` of the active transaction (or nil if free).
    @Published private(set) var expiresAt: Date?

    /// The product id the user purchased ("com.famoria.plus.monthly" or
    /// ".annual"), or nil if no active subscription.
    @Published private(set) var activeProductId: String?

    /// Last error surfaced from a purchase / restore so the paywall can
    /// show it inline. Reset to nil at the start of each new attempt.
    @Published var lastError: String?

    /// True while a purchase or restore is in flight; the paywall uses
    /// this to disable buttons + show a spinner.
    @Published var isPurchasing: Bool = false

    /// Set by SubscriptionSyncService once we're observing — `nil` means
    /// "no Firestore sync wired yet, treat changes as local-only".
    var onStatusChanged: (() async -> Void)?

    // MARK: - Private state

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init / lifecycle

    init() {
        // Begin listening to Transaction.updates as soon as the app boots
        // so renewals and revocations fire reliably even when the user
        // never opens the paywall.
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Product loading

    func loadProducts() async {
        let ids = FamoriaProduct.allCases.map(\.rawValue)
        do {
            let fetched = try await Product.products(for: ids)
            var dict: [String: Product] = [:]
            for product in fetched {
                dict[product.id] = product
            }
            self.products = dict
        } catch {
            Log.appState.error("loadProducts failed: \(error.localizedDescription, privacy: .public)")
            self.lastError = error.localizedDescription
        }
    }

    func product(_ kind: FamoriaProduct) -> Product? {
        products[kind.rawValue]
    }

    // MARK: - Purchase

    /// Initiates a StoreKit purchase. On success this calls
    /// `refreshEntitlement()` so `currentStatus` updates immediately
    /// without waiting for the listener.
    func purchase(_ kind: FamoriaProduct) async {
        guard let product = products[kind.rawValue] else {
            lastError = "Plan not available right now. Try again in a moment."
            return
        }

        lastError = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
            case .userCancelled:
                break
            case .pending:
                // Awaiting Ask-to-Buy / SCA. Refresh once the listener
                // signals the transaction state change.
                lastError = "Purchase pending approval. We'll unlock features as soon as it's confirmed."
            @unknown default:
                lastError = "Unexpected purchase result. Please try again."
            }
        } catch StoreError.failedVerification {
            lastError = "We couldn't verify that purchase with Apple. Please try again."
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Restores existing purchases by re-syncing with the App Store. The
    /// `Transaction.updates` listener should pick up anything new, but
    /// `AppStore.sync()` is the official "I just installed on a new
    /// device" entry point.
    func restorePurchases() async {
        lastError = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Walks the user's current entitlements and computes our derived
    /// `SubscriptionStatus`. Safe to call at any time.
    func refreshEntitlement() async {
        var foundActive = false
        var newStatus: SubscriptionStatus = .free
        var newExpires: Date?
        var newProductId: String?
        var trial = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            // Only Famoria Plus products are relevant.
            guard FamoriaProduct(rawValue: transaction.productID) != nil else { continue }

            if let revocationDate = transaction.revocationDate, revocationDate <= Date() {
                newStatus = .revoked
                continue
            }
            if let expiresDate = transaction.expirationDate, expiresDate < Date() {
                newStatus = .expired
                continue
            }

            foundActive = true
            newStatus = .active
            newExpires = transaction.expirationDate
            newProductId = transaction.productID

            // Look up the SubscriptionInfo to detect "off auto-renew" and
            // trial state.
            if let subStatus = try? await Product.SubscriptionInfo.status(for: transaction.subscriptionGroupID ?? "") {
                if let first = subStatus.first {
                    if case .verified(let renewal) = first.renewalInfo {
                        if !renewal.willAutoRenew {
                            newStatus = .willNotRenew
                        }
                    }
                    if first.state == .inBillingRetryPeriod {
                        newStatus = .inBillingRetry
                    }
                }
            }

            // Intro-offer detection — user is in their first 7-day trial
            // if the transaction has an `offerType == .introductory`.
            if transaction.offer?.type == .introductory {
                trial = true
            }
        }

        if !foundActive && newStatus == .free {
            // No active entitlements found — default to free tier.
            newStatus = .free
        }

        self.currentStatus = newStatus
        self.expiresAt = newExpires
        self.activeProductId = newProductId
        self.inTrial = trial

        if let onStatusChanged {
            await onStatusChanged()
        }
    }

    /// True if the signed-in user has *ever* purchased Famoria Plus —
    /// used to gate the 7-day free trial eligibility on the paywall.
    func hasEverPurchased() async -> Bool {
        for await result in Transaction.all {
            if case .verified(let txn) = result,
               FamoriaProduct(rawValue: txn.productID) != nil {
                return true
            }
        }
        return false
    }

    /// Opens Apple's "Manage Subscriptions" sheet so the user can cancel
    /// or change their plan. Must be called from a SwiftUI view that has
    /// a UIWindowScene in its environment.
    func openManageSubscriptions() async {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(update)
                    await transaction.finish()
                    await self.refreshEntitlement()
                } catch {
                    await MainActor.run {
                        self.lastError = "Couldn't verify a subscription update with Apple."
                    }
                }
            }
        }
    }

    // MARK: - Verification

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
