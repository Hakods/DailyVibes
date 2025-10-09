//
//  Formatters.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 6.10.2025.
//

// Shared/Formatters.swift
import Foundation

extension DateFormatter {
    /// Gün-anahtarı için sabit format: "yyyyMMdd"
    static let dayKey: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale   = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd"
        return df
    }()
}

