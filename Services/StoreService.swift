//
//  StoreService.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class StoreService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUnlocked: Bool = false

    private let proId = "pro_unlock"

    init() {
        Task {
            await loadProducts()
            await observeTransactions()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        do { products = try await Product.products(for: [proId]) }
        catch { print("Product load error:", error) }
    }

    func buyPro() async throws {
        guard let product = products.first(where: { $0.id == proId }) else { return }
        let result = try await product.purchase()
        if case .success(let v) = result, case .verified(let tx) = v {
            await tx.finish(); await refreshEntitlements()
        }
    }

    func restore() async {
        do { try await AppStore.sync() } catch { print("Restore error:", error) }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await ent in Transaction.currentEntitlements {
            if case .verified(let t) = ent, t.productID == proId { unlocked = true }
        }
        isProUnlocked = unlocked
    }

    private func observeTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let tx) = update {
                await tx.finish(); await refreshEntitlements()
            }
        }
    }
}
