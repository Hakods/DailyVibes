//
//  StoreService.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import StoreKit
import Combine

@MainActor // Tüm sınıfı MainActor'a alalım
final class StoreService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUnlocked: Bool = false
    
    private let monthlyProductID = "pro_monthly"
    private let yearlyProductID = "pro_yearly"
    private let allProductIDs: [String]
    
    private var updates: Task<Void, Never>? = nil
    
    init() {
        allProductIDs = [monthlyProductID, yearlyProductID]
        print("▶️ StoreService: init çağrıldı. Product IDs: \(allProductIDs)")
        updates = listenForUpdates()
        Task {
            await loadProducts()
#if !DEBUG
            print("   (Release Build): Başlangıçta abonelik durumu kontrol ediliyor...")
            await updateSubscriptionStatus()
#else
            print("   (Debug Build): Başlangıçta abonelik durumu kontrol EDİLMEDİ (isProUnlocked = false).")
#endif
        }
    }
    
    deinit {
        updates?.cancel() // Task'i iptal et
    }
    
    // DÜZELTME: Task döndüren @MainActor üzerinde bir fonksiyon
    private func listenForUpdates() -> Task<Void, Never> {
        Task { @MainActor [weak self] in // Bu Task @MainActor üzerinde çalışacak
            print("👂 StoreService: Transaction güncellemeleri dinleniyor...")
            guard !Task.isCancelled else {
                print("⏹️ StoreService: Dinleyici başlatılamadan iptal edildi.")
                return
            }
            // Transaction.updates async sequence, doğrudan await edilebilir
            for await result in Transaction.updates {
                print("   📬 Transaction güncellemesi alındı.")
                // Task iptal edildiyse döngüden çık
                if Task.isCancelled {
                    print("⏹️ StoreService: Dinleyici güncellemeyi işlerken iptal edildi.")
                    break
                }
                guard let self = self else { break }
                do {
                    // checkVerified @MainActor üzerinde, biz de öyleyiz, doğrudan çağır
                    let transaction = try self.checkVerified(result) // Tipi Transaction olmalı
                    print("   ✅ Transaction doğrulandı: \(transaction.productID)")
                    
                    // Durumu GÜNCELLE (zaten @MainActor üzerindeyiz)
                    await self.updateSubscriptionStatus()
                    
                    // Transaction'ı bitir (zaten @MainActor üzerindeyiz)
                    await transaction.finish()
                    print("   🏁 Transaction bitirildi: \(transaction.id)")
                } catch {
                    print("   🛑 Transaction işleme hatası: \(error)")
                }
            }
            print("⏹️ StoreService: Transaction dinleyici döngüsü bitti.")
        }
    }
    
    
    func loadProducts() async {
        do {
            // --- GÜNCELLEME: Tüm ID'leri kullanarak ürünleri yükle ---
            print("⏳ StoreService: Ürünler yükleniyor (IDs: \(allProductIDs))...")
            let storeProducts = try await Product.products(for: allProductIDs)
            
            // Ürünleri fiyata göre sıralayabiliriz (aylık önce)
            self.products = storeProducts.sorted { $0.price < $1.price }
            
            print("✅ StoreService: \(products.count) abonelik ürünü yüklendi.")
            for prod in products {
                print("   - Bulunan ID: \(prod.id), Fiyat: \(prod.displayPrice), Tip: \(prod.type.readableName)")
            }
            if products.isEmpty {
                print("   ⚠️ StoreService: Tanımlanan ID'lerle eşleşen ürün bulunamadı.")
            }
        } catch {
            print("🛑 StoreService: Ürün yükleme hatası: \(error.localizedDescription)")
        }
    }
    
    func buyProduct(_ product: Product) async throws /* -> Transaction? */ { // Transaction döndürme zorunlu değil
        print("🛒 StoreService: '\(product.id)' aboneliği satın alınıyor...")
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            print("   Verifying purchase...")
            let transaction = try checkVerified(verificationResult)
            print("   Purchase verified for transaction: \(transaction.id)")
            await updateSubscriptionStatus() // Durumu güncelle
            await transaction.finish()
            print("✅ StoreService: '\(product.id)' aboneliği başarıyla satın alındı/güncellendi.")
            // return transaction // İstersen döndürebilirsin
        case .userCancelled:
            print("   ℹ️ StoreService: Kullanıcı satın almayı iptal etti.")
            throw StoreKitError.userCancelled
        case .pending:
            print("   ⏳ StoreService: Satın alma beklemede (Ask to Buy vb.).")
            throw StoreError.paymentPending
        @unknown default:
            print("   ❓ StoreService: Bilinmeyen satın alma sonucu.")
            throw StoreError.unknown
        }
        // return nil // Başarısız veya iptal durumunda
    }
    
    @discardableResult
    func updateSubscriptionStatus() async -> Bool {
        var hasActiveSubscription = false
        print("🔁 StoreService: Abonelik durumu kontrol ediliyor (IDs: \(allProductIDs))...")
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Otomatik yenilenebilir ve bizim Pro ID'lerimizden biri ise
                if transaction.productType == .autoRenewable && allProductIDs.contains(transaction.productID) {
                    // İptal edilmemiş, süresi dolmamış ve yükseltilmemişse
                    if transaction.revocationDate == nil && !transaction.isUpgraded && (transaction.expirationDate ?? .distantPast) > Date() {
                        print("   - Aktif abonelik bulundu: \(transaction.productID), Bitiş: \(transaction.expirationDate?.formatted() ?? "N/A")")
                        hasActiveSubscription = true
                        break // Aktif bir tane bulmak yeterli
                    } else {
                        print("   - Geçersiz (iptal/dolmuş/yükseltilmiş) abonelik bulundu: \(transaction.productID)")
                    }
                }
            } catch {
                print("   ⚠️ StoreService: Yetki kontrolü sırasında hata: \(error)")
            }
        }
        
        self.isProUnlocked = hasActiveSubscription
        print("   ▶️ StoreService: isProUnlocked durumu: \(self.isProUnlocked)")
        return self.isProUnlocked
    }
    
    func restore() async {
        print("🔄 StoreService: Satın alımlar geri yükleniyor...")
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ StoreService: Geri yükleme tamamlandı.")
        } catch {
            print("🛑 StoreService: Geri yükleme hatası: \(error)")
        }
    }
    
    
    // DÜZELTME: Fonksiyon Transaction'a özgü, generic değil
    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(let transaction, let error):
            print("   ❌ Doğrulanamayan Transaction (\(transaction.id)): \(error.localizedDescription)")
            throw StoreError.verificationFailed(error)
        case .verified(let transaction):
            return transaction // Doğrulanmış Transaction'ı döndür
        }
    }
    
    // Hata tiplerimiz
    enum StoreError: Error {
        case productNotFound
        case verificationFailed(VerificationResult<Transaction>.VerificationError)
        case paymentPending
        case unknown // unknownPurchaseResult yerine
    }
}

// ProductType için readableName (Warning devam eder ama çalışır)
extension Product.ProductType {
    var readableName: String {
        switch self {
        case .autoRenewable: return "Auto-Renewable Subscription"
        case .consumable: return "Consumable"
        case .nonConsumable: return "Non-Consumable"
        case .nonRenewable: return "Non-Renewing Subscription"
        default:
            print("⚠️ Bilinmeyen Product.ProductType ile karşılaşıldı: \(self)")
            return "Bilinmeyen Ürün Tipi"
        }
    }
}
