//
//  PremiumStore.swift
//  Focus Forest Adventure
//
//  StoreKit 2 subscription store. Free tier: 3 missions/day, forest levels 1–4.
//  Forest Plus: unlimited missions, all forest levels, all adventures.
//  No ads, no third-party tracking — ever (kids app).
//

import Foundation
import StoreKit
import Observation

@Observable
@MainActor
final class PremiumStore {

    enum ProductID {
        static let monthlyPlus = "com.focusforest.plus.monthly"
        static let yearlyPlus = "com.focusforest.plus.yearly"
        static let all = [monthlyPlus, yearlyPlus]
    }

    private(set) var products: [Product] = []
    private(set) var isPlusSubscriber = false
    private(set) var isLoading = false

    private var updatesTask: Task<Void, Never>?

    init() {
        // Listen for transaction updates for the app's lifetime.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    isolated deinit { updatesTask?.cancel() }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
        await updateEntitlements()
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await updateEntitlements()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateEntitlements()
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
            await updateEntitlements()
        }
    }

    private func updateEntitlements() async {
        var isSubscribed = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                isSubscribed = true
            }
        }
        isPlusSubscriber = isSubscribed
    }

    /// Free-tier gate: 3 missions per day.
    func canStartMission(completedToday: Int) -> Bool {
        isPlusSubscriber || completedToday < 3
    }
}
