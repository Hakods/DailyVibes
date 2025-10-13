//
//  TimeWindow.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation

enum TimeWindow {
    static func randomTime(on day: Date, startHour: Int, endHour: Int) -> Date? {
        let cal = Calendar.current
        guard
          let start = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
          let end   = cal.date(bySettingHour: endHour, minute: 0, second: 0, of: day),
          end > start
        else { return nil }

        // toplam saniye, son 10 dakikayı bırak (cevap penceresi için yer)
        let span = Int(end.timeIntervalSince(start)) - 10*60
        guard span > 0 else { return nil }

        let offset = Int.random(in: 0...span)            // her build/çağrıda farklı
        var result = start.addingTimeInterval(TimeInterval(offset))

        // dakikaya yuvarla
        let comps = cal.dateComponents([.year,.month,.day,.hour,.minute], from: result)
        result = cal.date(from: comps) ?? result
        return result
    }

    static func expiry(for fire: Date) -> Date {
        fire.addingTimeInterval(10*60) // 10 dk pencere
    }
}
