//
//  APIKeyLoader.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 5.11.2025.
//

import Foundation

enum APIKeyLoader {
    /// "Keys.plist" dosyasından bir API anahtarını güvenle yükler.
    /// BU DOSYANIN (Keys.plist) .gitignore'DA OLDUĞUNDAN EMİN OLUN.
    static func loadAPIKey(named keyName: String) -> String {
        guard let filePath = Bundle.main.path(forResource: "Keys", ofType: "plist") else {
            fatalError("GÜVENLİK DÜZELTMESİ: 'Keys.plist' dosyası projede bulunamadı. Lütfen 3. adımı uygulayın.")
        }
        
        guard let plist = NSDictionary(contentsOfFile: filePath),
              let key = plist.object(forKey: keyName) as? String,
              !key.isEmpty,
              !key.starts(with: "AIzaSyAu2J4rxq6OLS_SSyiZkcZLsgHgYq9RTBI")
        else {
            fatalError("GÜVENLİK DÜZELTMESİ: '\(keyName)' anahtarı 'Keys.plist' içinde bulunamadı veya hâlâ varsayılan değerde. Lütfen 3. adımdaki 'Keys.plist' dosyasını oluşturup anahtarınızı girin.")
        }
        
        return key
    }
}
