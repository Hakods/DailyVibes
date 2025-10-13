//
//  ScheduleService.swift
//  Daily Vibes
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class ScheduleService: ObservableObject {
    @Published var startHour: Int = 10
    @Published var endHour: Int = 22
    @Published var pingsPerDay: Int = 1   // ileride Pro için 1..3'e çıkarılabilir

    private let repo: DayEntryRepository
    private let notifier: NotificationService

    /// "Bugün toplu plan yaptık mı?" throttling için basit bir bayrak
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
        guard canPlanToday() else {
            #if DEBUG
            print("⚠️ planForNext() SKIPPED (throttled for today)")
            #endif
            return
        }

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

        #if DEBUG
        print("🔄 Planlama başlıyor… \(days) gün için (window: \(startHour):00–\(endHour):00)")
        #endif

        // 2) Bugün dâhil ileri günleri planla (her gün tek bildirim)
        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: i, to: today),
                  let fire = randomTime(on: day, startHour: startHour, endHour: endHour)
            else { continue }

            // BUGÜN ve rastgele saat geçmişse: o günü atla (spam’i önler)
            if cal.isDate(day, inSameDayAs: today), fire <= now { continue }

            let exp = expiry(for: fire)

            if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: day) }) {
                entries[idx].scheduledAt = fire
                entries[idx].expiresAt   = exp
                entries[idx].status      = .pending
                entries[idx].text        = nil
                entries[idx].allowEarlyAnswer = false
            } else {
                entries.append(DayEntry(day: day, scheduledAt: fire, expiresAt: exp))
            }

            // Aynı güne ait önceki pending’i iptal edip tek bir bildirim bırak
            try? await notifier.scheduleUniqueDaily(for: day, at: fire)

            #if DEBUG
            let df = DateFormatter(); df.dateFormat = "dd MMM yyyy, HH:mm"
            print("✅ Planlandı → \(df.string(from: fire))  [id: mood-\(DateFormatter.dayKey.string(from: day))]")
            #endif
        }

        try? repo.save(entries)
        markPlannedToday()

        // Bekleyen bildirimleri özetle
        #if DEBUG
        await logPendingSummary()
        #endif
    }

    /// Admin: 1 dk sonra **tekil** bildirim planla (bugün için). Erken cevap modunu açar.
    func planAdminOneMinute() async {
        var entries = (try? repo.load()) ?? []
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        guard let fire = cal.date(byAdding: .second, value: 60, to: now) else { return }
        let exp = expiry(for: fire)

        if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: today) }) {
            entries[idx].scheduledAt = fire
            entries[idx].expiresAt   = exp
            entries[idx].status      = .pending
            entries[idx].text        = nil
            entries[idx].allowEarlyAnswer = true
        } else {
            entries.append(DayEntry(day: today,
                                    scheduledAt: fire,
                                    expiresAt: exp,
                                    allowEarlyAnswer: true))
        }

        try? repo.save(entries)
        try? await notifier.scheduleUniqueDaily(for: today, at: fire)

        #if DEBUG
        let df = DateFormatter(); df.dateFormat = "dd MMM yyyy, HH:mm:ss"
        print("⚡️ Admin planı → \(df.string(from: fire))  [id: mood-\(DateFormatter.dayKey.string(from: today))]")
        await logPendingSummary()
        #endif
    }

    /// Belirli bir saate **tekil** bildirim planla (aynı güne eskileri iptal eder).
    func planTestNotification(at date: Date) async {
        var entries = (try? repo.load()) ?? []
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let exp  = expiry(for: date)

        if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: day) }) {
            entries[idx].scheduledAt = date
            entries[idx].expiresAt   = exp
            entries[idx].status      = .pending
            entries[idx].text        = nil
            entries[idx].allowEarlyAnswer = false
        } else {
            entries.append(DayEntry(day: day, scheduledAt: date, expiresAt: exp))
        }

        try? repo.save(entries)
        try? await notifier.scheduleUniqueDaily(for: day, at: date)

        #if DEBUG
        let df = DateFormatter(); df.dateFormat = "dd MMM yyyy, HH:mm"
        print("🧪 Test planı → \(df.string(from: date))  [id: mood-\(DateFormatter.dayKey.string(from: day))]")
        await logPendingSummary()
        #endif
    }

    // MARK: - Private helpers (TimeWindow bağımsız)

    /// Verilen gün için [startHour, endHour) aralığında rastgele bir saat/min üretir.
    private func randomTime(on day: Date, startHour: Int, endHour: Int) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        guard startHour < endHour else { return nil }
        let hour = Int.random(in: startHour..<endHour)
        let minute = Int.random(in: 0..<60)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)
    }

    /// Bildirimin bitiş süresi (default: +10 dakika)
    private func expiry(for scheduled: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: 10, to: scheduled) ?? scheduled.addingTimeInterval(600)
    }

    /// Bekleyen istekleri konsola özetle (ID + tetik zamanı)
    private func logPendingSummary() async {
        let df = DateFormatter(); df.dateFormat = "dd MMM yyyy, HH:mm:ss"
        let reqs = await notifier.pendingRequests()
        let ours = reqs.filter { $0.identifier.hasPrefix("mood-") || $0.identifier.hasPrefix("test-") || $0.identifier.hasPrefix("admin-") }
        print("📬 Pending(\(ours.count)) —")
        for r in ours {
            if let trig = r.trigger as? UNCalendarNotificationTrigger,
               let fire = trig.nextTriggerDate() {
                print(" • \(r.identifier) → \(df.string(from: fire))")
            } else if let trig = r.trigger as? UNTimeIntervalNotificationTrigger {
                print(" • \(r.identifier) → in \(Int(trig.timeInterval))s (repeats: \(trig.repeats))")
            } else {
                print(" • \(r.identifier) → (unknown trigger)")
            }
        }
    }
}
