//
//  TimeWindow.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation

struct TimeWindow {
    static func randomTime(on day: Date, startHour: Int, endHour: Int) -> Date? {
        let cal = Calendar.current
        guard let s = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
              let e = cal.date(bySettingHour: endHour, minute: 0, second: 0, of: day),
              e > s else { return nil }
        let delta = e.timeIntervalSince(s)
        return s.addingTimeInterval(TimeInterval.random(in: 0..<delta))
    }
    static func expiry(for scheduledAt: Date) -> Date { scheduledAt.addingTimeInterval(10 * 60) }
    static func isWithinWindow(now: Date, scheduledAt: Date) -> Bool {
        now >= scheduledAt && now <= expiry(for: scheduledAt)
    }
}
