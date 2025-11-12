
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
    
    private var currentLangCode: String = "system"
    private(set) var currentBundle: Bundle = .main
    
    init(store: StoreService) {
        self.store = store
        if store.products.isEmpty {
            Task { await store.loadProducts() }
        }
    }
    
    func updateLanguage(langCode: String) {
        let newCode: String
        if langCode == "system" {
            newCode = Bundle.main.preferredLocalizations.first ?? "en"
        } else {
            newCode = langCode
        }
        
        guard newCode != self.currentLangCode else { return }
        
        self.currentLangCode = newCode
        
        if let path = Bundle.main.path(forResource: newCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.currentBundle = bundle
        } else {
            self.currentBundle = .main
        }

        if errorMessage != nil {
            errorMessage = nil
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
                errorMessage = NSLocalizedString("paywall.restore.success", bundle: self.currentBundle, comment: "Restore success")
            } else {
                errorMessage = NSLocalizedString("paywall.restore.notFound", bundle: self.currentBundle, comment: "Restore not found")
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
                    let format = NSLocalizedString("paywall.error.network", bundle: self.currentBundle, comment: "Network error")
                    errorMessage = String(format: format, underlyingError.code)
                } else {
                    errorMessage = NSLocalizedString("paywall.error.unknownSK", bundle: self.currentBundle, comment: "Unknown SK error")
                }
            case .clientInvalid: errorMessage = NSLocalizedString("paywall.error.clientInvalid", bundle: self.currentBundle, comment: "Client invalid")
            case .paymentCancelled: errorMessage = nil
            case .paymentInvalid: errorMessage = NSLocalizedString("paywall.error.paymentInvalid", bundle: self.currentBundle, comment: "Payment invalid")
            case .paymentNotAllowed: errorMessage = NSLocalizedString("paywall.error.paymentNotAllowed", bundle: self.currentBundle, comment: "Payment not allowed")
            case .storeProductNotAvailable: errorMessage = NSLocalizedString("paywall.error.productNotAvailable", bundle: self.currentBundle, comment: "Product not available")
            default:
                let format = NSLocalizedString("paywall.error.defaultSK", bundle: self.currentBundle, comment: "Default SK error")
                errorMessage = String(format: format, nsError.code)
            }
        } else if let storeError = error as? StoreService.StoreError {
            switch storeError {
            case .productNotFound: errorMessage = NSLocalizedString("paywall.error.productNotFound", bundle: self.currentBundle, comment: "Product not found")
            case .verificationFailed: errorMessage = NSLocalizedString("paywall.error.verificationFailed", bundle: self.currentBundle, comment: "Verification failed")
            case .paymentPending: errorMessage = NSLocalizedString("paywall.error.paymentPending", bundle: self.currentBundle, comment: "Payment pending")
            case .unknown: errorMessage = NSLocalizedString("paywall.error.unknownStore", bundle: self.currentBundle, comment: "Unknown store error")
            }
        } else {
            let format = NSLocalizedString("paywall.error.genericPrefix", bundle: self.currentBundle, comment: "Generic error prefix")
            errorMessage = String(format: format, error.localizedDescription)
        }
    }
}
