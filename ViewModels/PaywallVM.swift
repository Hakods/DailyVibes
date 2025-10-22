//
//  PaywallVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import Combine
import StoreKit

@MainActor
final class PaywallVM: ObservableObject {
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    let store: StoreService

    init(store: StoreService) {
        self.store = store
        Task { await store.loadProducts() }
    }


    func buy() {
        Task { @MainActor in
            isPurchasing = true
            errorMessage = nil // Başlangıçta hata mesajını temizle
            // defer { isPurchasing = false } // Hata mesajı gösterilecekse hemen false yapmayalım

            do {
                try await store.buyProSubscription()
                // Başarılı olursa purchasing'i false yap
                isPurchasing = false
            } catch {
                isPurchasing = false // Hata durumunda da false yap
                print("🛑 PaywallVM: Satın alma hatası yakalandı: \(error)")

                let nsError = error as NSError // Hatayı NSError'a çevirelim

                // 1. ÖNCELİK: StoreKit'in kendi domain'indeki (SKErrorDomain) hataları kodlarına göre işle
                if nsError.domain == SKErrorDomain {
                    switch nsError.code {
                    case SKError.unknown.rawValue:
                        errorMessage = "Bilinmeyen bir satın alma hatası oluştu."
                    case SKError.clientInvalid.rawValue:
                        errorMessage = "Satın alma işlemi başlatılamadı."
                    case SKError.paymentCancelled.rawValue:
                        errorMessage = nil
                    case SKError.paymentInvalid.rawValue:
                        errorMessage = "Ödeme bilgileri geçersiz."
                    case SKError.paymentNotAllowed.rawValue:
                        errorMessage = "Satın alma yetkiniz yok."
                    case SKError.storeProductNotAvailable.rawValue:
                        errorMessage = "Ürün mağazada mevcut değil."
                    default:
                        if nsError.domain == SKErrorDomain && nsError.code == 5 {
                            errorMessage = "Ağ hatası oluştu. İnternet bağlantınızı kontrol edin."
                        } else {
                            errorMessage = "Bir StoreKit sorunu oluştu (Kod: \(nsError.code)). \(error.localizedDescription)"
                        }
                    }
                // 2. ÖNCELİK: Bizim tanımladığımız StoreService hataları
                } else if let storeError = error as? StoreService.StoreError {
                     switch storeError {
                     case .productNotFound:
                         errorMessage = "Abonelik ürünü bulunamadı. Lütfen daha sonra tekrar deneyin."
                     case .verificationFailed:
                         errorMessage = "Satın alma doğrulanamadı. Lütfen tekrar deneyin."
                     case .paymentPending:
                         errorMessage = "Ödeme beklemede (Ask to Buy vb.). Onaylandığında erişiminiz açılacaktır."
                     case .unknown:
                          errorMessage = "Satın alma sonucu bilinmiyor."
                     }
                // 3. ÖNCELİK: Diğer tüm hatalar
                } else {
                     errorMessage = "Satın alma başarısız oldu. Lütfen tekrar deneyin."
                }
            }
        }
    }

    func restore() {
        Task { @MainActor in
            isPurchasing = true; defer { isPurchasing = false }
            errorMessage = nil // Başlangıçta temizle
            await store.restore()
            if store.isProUnlocked {
                errorMessage = "Satın alımlar başarıyla geri yüklendi." // Başarı
            } else {
                errorMessage = "Geri yüklenecek aktif bir abonelik bulunamadı." // Bilgi
            }
        }
    }
}
