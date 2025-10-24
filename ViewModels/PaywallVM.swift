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
        if store.products.isEmpty {
            Task { await store.loadProducts() }
        }
    }
    
    func buyProduct(_ product: Product) {
        Task { @MainActor in
            isPurchasing = true
            errorMessage = nil
            
            do {
                try await store.buyProduct(product)
                isPurchasing = false
            } catch {
                isPurchasing = false
                handlePurchaseError(error)
            }
        }
    }
    
    func restore() {
        Task { @MainActor in
            isPurchasing = true
            errorMessage = nil
            await store.restore()
            isPurchasing = false
            if store.isProUnlocked {
                errorMessage = "Satın alımlar başarıyla geri yüklendi."
            } else {
                errorMessage = "Geri yüklenecek aktif bir abonelik bulunamadı."
            }
        }
    }
    
    private func handlePurchaseError(_ error: Error) {
        print("🛑 PaywallVM: Satın alma hatası yakalandı: \(error)")
        let nsError = error as NSError
        
        if nsError.domain == SKErrorDomain {
            switch SKError.Code(rawValue: nsError.code) {
            case .unknown:
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
                   underlyingError.domain == NSURLErrorDomain {
                    errorMessage = "Ağ hatası oluştu. İnternet bağlantınızı kontrol edin (Kod: \(underlyingError.code))."
                } else {
                    errorMessage = "Bilinmeyen bir satın alma hatası oluştu. Lütfen tekrar deneyin."
                }
            case .clientInvalid: errorMessage = "Satın alma işlemi başlatılamadı (Geçersiz istemci)."
            case .paymentCancelled: errorMessage = nil
            case .paymentInvalid: errorMessage = "Ödeme bilgileri geçersiz."
            case .paymentNotAllowed: errorMessage = "Bu cihazda satın alma yetkiniz yok."
            case .storeProductNotAvailable: errorMessage = "Ürün şu anda mağazada mevcut değil."
            default: errorMessage = "Bir App Store sorunu oluştu (Kod: \(nsError.code)). Lütfen tekrar deneyin."
            }
        } else if let storeError = error as? StoreService.StoreError {
            switch storeError {
            case .productNotFound: errorMessage = "Abonelik ürünü bulunamadı. Lütfen daha sonra tekrar deneyin."
            case .verificationFailed: errorMessage = "Satın alma doğrulanamadı. Apple Kimliğinizle ilgili bir sorun olabilir."
            case .paymentPending: errorMessage = "Ödeme beklemede (Ask to Buy vb.). Onaylandığında erişiminiz açılacaktır."
            case .unknown: errorMessage = "Bilinmeyen bir satın alma sonucu. Lütfen tekrar deneyin."
            }
        } else {
            errorMessage = "Satın alma başarısız oldu: \(error.localizedDescription)"
        }
    }
}
