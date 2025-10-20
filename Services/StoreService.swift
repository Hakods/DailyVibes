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
    // purchasedProductIDs'ye abonelik için gerek yok gibi, istersen kaldırabilirsin
    // @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var isProUnlocked: Bool = false

    private let proSubscriptionId = "pro_monthly"

    private var updates: Task<Void, Never>? = nil

    init() {
        print("▶️ StoreService: init çağrıldı.")
        // init @MainActor üzerinde olduğu için Task başlatmak güvenli
        updates = listenForUpdates() // Dinleyiciyi başlat (Task döndürüyor)

        // Ürünleri ve durumu yüklemek için ayrı bir Task
        Task {
            await loadProducts()
            
            // --- DEĞİŞİKLİK BURADA ---
#if !DEBUG // DEBUG modunda DEĞİLSE (yani Release modundaysa) başlangıçta durumu kontrol et
            print("   (Release Build): Başlangıçta abonelik durumu kontrol ediliyor...")
            await updateSubscriptionStatus()
#else // DEBUG modundaysa durumu kontrol ETME, false olarak başlasın
            print("   (Debug Build): Başlangıçta abonelik durumu kontrol EDİLMEDİ (isProUnlocked = false).")
            // isProUnlocked zaten false olarak başlıyor, bir şey yapmaya gerek yok.
#endif
            // --- DEĞİŞİKLİK SONU ---
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
            print("⏳ StoreService: Ürünler yükleniyor (ID: \(proSubscriptionId))...")
            let subscriptionProducts = try await Product.products(for: [proSubscriptionId])
            // @MainActor üzerinde olduğumuz için self.products'a doğrudan atama yapabiliriz
            self.products = subscriptionProducts
            print("✅ StoreService: \(products.count) abonelik ürünü yüklendi.")
            if let proSub = products.first {
                print("   - Bulunan Abonelik ID: \(proSub.id), Fiyat: \(proSub.displayPrice), Tip: \(proSub.type.readableName)")
 // readableName kullandık
            } else {
                 print("   ⚠️ StoreService: '\(proSubscriptionId)' ID'li abonelik ürünü bulunamadı.")
            }
        } catch {
            print("🛑 StoreService: Ürün yükleme hatası: \(error.localizedDescription)")
        }
    }

    func buyProSubscription() async throws {
        guard let product = products.first(where: { $0.id == proSubscriptionId }) else {
             print("🛑 StoreService: Satın alınacak abonelik ürünü bulunamadı.")
             throw StoreError.productNotFound
        }

        print("🛒 StoreService: '\(product.id)' aboneliği satın alınıyor...")
        let result = try await product.purchase() // result: Product.PurchaseResult

        // DÜZELTME: result'ı switch ile doğru şekilde işle
        switch result {
        case .success(let verificationResult): // verificationResult: VerificationResult<Transaction>
            print("   Verifying purchase...")
            // DÜZELTME: verificationResult'ı checkVerified'a ver
            let transaction = try checkVerified(verificationResult)
            print("   Purchase verified for transaction: \(transaction.id)")
            await updateSubscriptionStatus()
            await transaction.finish()
            print("✅ StoreService: '\(product.id)' aboneliği başarıyla satın alındı/güncellendi.")
        case .userCancelled:
            print("   ℹ️ StoreService: Kullanıcı satın almayı iptal etti.")
            throw StoreKitError.userCancelled // PaywallVM'de yakalamak için fırlat
        case .pending:
            print("   ⏳ StoreService: Satın alma beklemede (Ask to Buy vb.).")
            throw StoreError.paymentPending // PaywallVM'de yakalamak için fırlat
        @unknown default:
            print("   ❓ StoreService: Bilinmeyen satın alma sonucu.")
            throw StoreError.unknown
        }
    }
    
#if DEBUG
    /// SADECE DEBUG: isProUnlocked durumunu 'false' yapar.
    func resetProStatusForDebug() {
        print("⚠️ DEBUG ACTION: Pro durumu sıfırlanıyor (isProUnlocked = false).")
        self.isProUnlocked = false
        // İsteğe bağlı: Arayüzün güncellenmesi için @Published değişkeni tetiklendi
        // objectWillChange.send() // Genellikle gerekmez, @Published yeterli olur
    }
#endif

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

    @discardableResult
    func updateSubscriptionStatus() async -> Bool {
        var hasActiveSubscription = false
        print("🔁 StoreService: Abonelik durumu kontrol ediliyor...")

        // Mevcut tüm yetkileri (entitlements) kontrol et
        for await result in Transaction.currentEntitlements { // result: VerificationResult<Transaction>
            do {
                // DÜZELTME: Bu çağrı artık doğru olmalı
                let transaction = try checkVerified(result) // Tipi Transaction olmalı

                if transaction.productType == .autoRenewable && transaction.productID == proSubscriptionId {
                     if transaction.revocationDate == nil && !transaction.isUpgraded {
                        print("   - Aktif abonelik bulundu: \(transaction.productID)")
                        hasActiveSubscription = true
                     } else {
                        print("   - Geçersiz (iptal/dolmuş/yükseltilmiş) abonelik bulundu: \(transaction.productID)")
                     }
                }
            } catch {
                print("   ⚠️ StoreService: Yetki kontrolü sırasında hata: \(error)")
            }
        }

        // @MainActor üzerinde olduğumuz için self.isProUnlocked'a doğrudan atama yapabiliriz
        self.isProUnlocked = hasActiveSubscription
        print("   ▶️ StoreService: isProUnlocked durumu: \(self.isProUnlocked)")
        return self.isProUnlocked
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
        // DÜZELTME: Explicitly handle known cases and keep @unknown default
        default:
            // Bu durum Apple yeni bir tip eklediğinde ortaya çıkar, loglamak iyi olabilir.
            print("⚠️ Bilinmeyen Product.ProductType ile karşılaşıldı: \(self)")
            return "Bilinmeyen Ürün Tipi"
        }
    }
}
