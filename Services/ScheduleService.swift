//
//  ScheduleService.swift
//  Daily Vibes
//

import Foundation
import Combine

@MainActor
final class ScheduleService: ObservableObject {
    @Published var startHour: Int = 10
    @Published var endHour: Int = 22
    @Published var pingsPerDay: Int = 1   // ileride Pro için 1..3'e çıkarılabilir
    
    private let repo: DayEntryRepository
    private let notifier: NotificationService

    // "Bugün toplu plan yaptık mı?" throttling için basit bir bayrak
    private let lastPlanKey = "lastPlanDayKey"

    init(repo: DayEntryRepository? = nil,
         notifier: NotificationService? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        self.notifier = notifier ?? RepositoryProvider.shared.notification
    }

    // MARK: - Throttle helpers

    private func canPlanToday() -> Bool {
        let key = DateFormatter.dayKey.string(from: Date())
        let last = UserDefaults.standard.string(forKey: lastPlanKey)
        return last != key
    }

    private func markPlannedToday() {
        let key = DateFormatter.dayKey.string(from: Date())
        UserDefaults.standard.set(key, forKey: lastPlanKey)
    }

    // MARK: - Public APIs

    /// Önümüzdeki N günü planla; her gün için **tek** mood- bildirim bırak.
    /// - Gün içinde bu fonksiyon birden fazla çağrılsa bile throttle eder.
    func planForNext(days: Int = 14) async {
        // Günlük throttle: aynı gün içinde bir kez çalışsın
        guard canPlanToday() else { return }

        var entries = (try? repo.load()) ?? []
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        // 1) Geçmiş pending'leri "missed" yap
        for i in -30..<0 {
            if let d = cal.date(byAdding: .day, value: i, to: today),
               let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: d) }),
               entries[idx].status == .pending,
               now > entries[idx].expiresAt {
                entries[idx].status = .missed
            }
        }

        // 2) Bugün dahil ileri günleri planla (her gün için tek bildirim)
        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: i, to: today),
                  let fire = TimeWindow.randomTime(on: day, startHour: startHour, endHour: endHour)
            else { continue }

            // BUGÜN ve rastgele saat geçmişse: o günü es geç (spam'i önler)
            if cal.isDate(day, inSameDayAs: today), fire <= now { continue }

            let exp = TimeWindow.expiry(for: fire)

            if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: day) }) {
                // zaten kayıt varsa güncelle ve pending'e çek
                entries[idx].scheduledAt = fire
                entries[idx].expiresAt = exp
                entries[idx].status = .pending
                entries[idx].text = nil
                entries[idx].allowEarlyAnswer = false
            } else {
                // yeni kayıt oluştur
                entries.append(DayEntry(day: day, scheduledAt: fire, expiresAt: exp))
            }

            // Aynı güne ait önceki pending'i iptal edip tek bir bildirim bırak
            try? await notifier.scheduleUniqueDaily(for: day, at: fire)
        }

        try? repo.save(entries)
        markPlannedToday()
    }

    /// Admin: 1 dk sonra **tekil** bildirim planla (bugün için). Erken cevap modunu açar.
    func planAdminOneMinute() async {
        var entries = (try? repo.load()) ?? []
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        guard let fire = cal.date(byAdding: .second, value: 60, to: now) else { return }
        let exp = TimeWindow.expiry(for: fire)

        if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: today) }) {
            entries[idx].scheduledAt = fire
            entries[idx].expiresAt = exp
            entries[idx].status = .pending
            entries[idx].text = nil
            entries[idx].allowEarlyAnswer = true
        } else {
            entries.append(DayEntry(day: today,
                                    scheduledAt: fire,
                                    expiresAt: exp,
                                    allowEarlyAnswer: true))
        }

        try? repo.save(entries)
        try? await notifier.scheduleUniqueDaily(for: today, at: fire)
    }

    /// Belirli bir saate **tekil** bildirim planla (aynı güne eskileri iptal eder).
    func planTestNotification(at date: Date) async {
        var entries = (try? repo.load()) ?? []
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let exp = TimeWindow.expiry(for: date)

        if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: day) }) {
            entries[idx].scheduledAt = date
            entries[idx].expiresAt = exp
            entries[idx].status = .pending
            entries[idx].text = nil
            entries[idx].allowEarlyAnswer = false
        } else {
            entries.append(DayEntry(day: day, scheduledAt: date, expiresAt: exp))
        }

        try? repo.save(entries)
        try? await notifier.scheduleUniqueDaily(for: day, at: date)
    }
}
