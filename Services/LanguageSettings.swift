//
//  LanguageSettings.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 31.10.2025.
//

import SwiftUI
import Combine

enum LanguageCode: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case turkish = "tr"
    
    var id: String { self.rawValue }
    
    // Picker'da görünecek isim
    var displayName: String {
        switch self {
        case .system:
            return "Sistem (Default)"
        case .english:
            return "English"
        case .turkish:
            return "Türkçe"
        }
    }
}

// Seçilen dili saklayan ve uygulama genelinde yayınlayan sınıf
class LanguageSettings: ObservableObject {
    
    // AppStorage kullanarak kullanıcının seçimini UserDefaults'a otomatik kaydet
    @AppStorage("appLanguage") var selectedLanguageCode: String = LanguageCode.system.rawValue {
        didSet {
            // Değişiklik olduğunda objectWillChange'i manuel tetikle
            // (Bazen AppStorage'ın yayınlaması gecikebiliyor, bu garanti eder)
            objectWillChange.send()
        }
    }

    // String kodu (örn: "en") bir Locale objesine çeviren yardımcı değişken
    var computedLocale: Locale? {
        if selectedLanguageCode == LanguageCode.system.rawValue {
            return nil // 'nil' döndürmek SwiftUI'a "cihazın dilini kullan" der
        }
        return Locale(identifier: selectedLanguageCode)
    }
}
