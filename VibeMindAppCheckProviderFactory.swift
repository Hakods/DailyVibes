//
//  VibeMindAppCheckProviderFactory.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 11.11.2025.
//


import Foundation
import FirebaseCore
import FirebaseAppCheck
import DeviceCheck // Bu import'un burada da olması önemli

// Bu, Firebase'in bizden istediği "fabrika" sınıfıdır.
// Görevi, DEBUG modunda DebugProvider'ı, RELEASE modunda AppAttestProvider'ı oluşturmaktır.
// Ama biz bu mantığı zaten AppDelegate'de yaptığımız için, bu sınıf SADECE AppAttest'i döndürecek.

// ÖNEMLİ DÜZELTME:
// Aslında, Firebase dökümanları[1.4] DEBUG/RELEASE mantığının tam da bu dosyada yapılmasını ister.
// AppDelegate'i temizleyip tüm mantığı buraya alalım.

class VibeMindAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        // 'providerFactory' değişkenini AppDelegate'den buraya taşıdık.
        // Bu sınıf, doğru sağlayıcıyı (provider) oluşturmaktan sorumlu olacak.
        
        #if DEBUG
            // DEBUG modunda (Simülatör veya Xcode'dan çalıştırma):
            // 'AppCheckDebugProvider' kullan.
            print("🔔 App Check: DEBUG modu aktif (VibeMindAppCheckProviderFactory).")
            return AppCheckDebugProvider(app: app)
        #else
            // RELEASE modunda (TestFlight veya App Store):
            // Gerçek 'AppAttestProvider' kullan.
            print("🔒 App Check: RELEASE (App Attest) modu aktif (VibeMindAppCheckProviderFactory).")
            return AppAttestProvider(app: app)
        #endif
    }
}
