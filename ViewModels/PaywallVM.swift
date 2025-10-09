//
//  PaywallVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import Combine

@MainActor
final class PaywallVM: ObservableObject {
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    let store: StoreService

    init(store: StoreService) { self.store = store }

    func buy() {
        Task { @MainActor in
            isPurchasing = true; defer { isPurchasing = false }
            do { try await store.buyPro() }
            catch { errorMessage = "Satın alma başarısız. Lütfen tekrar deneyin." }
        }
    }

    func restore() { Task { @MainActor in await store.restore() } }
}
