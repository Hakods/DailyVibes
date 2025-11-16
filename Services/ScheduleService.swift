//
//  ScheduleService.swift
//  Daily Vibes
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class ScheduleService: ObservableObject {
    private let fixedStartHour = 10
    private let fixedEndHour = 22
    @Published private(set) var lastManualPlanAt: Date?

    private let repo: DayEntryRepository
    private let notifier: NotificationService
    private let defaults: UserDefaults
    private let languageSettings: LanguageSettings // YENİ

    private let lastPlanKey = "lastPlanDayKey"
    private let lastPlanTimestampKey = "lastPlanTimestampKey"

    private let firstPlanDateKey = "firstPlanDateKey"
    
    // GÜNCELLENDİ: 'init' artık 'languageSettings' alıyor
    init(repo: DayEntryRepository? = nil,
         notifier: NotificationService? = nil,
         languageSettings: LanguageSettings) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        self.notifier = notifier ?? RepositoryProvider.shared.notification
        self.defaults = UserDefaults.standard
        self.languageSettings = languageSettings // YENİ
        self.lastManualPlanAt = defaults.object(forKey: lastPlanTimestampKey) as? Date
    }

    // MARK: - Throttle helpers

    private func canPlanToday() -> Bool {
        let key = DateFormatter.dayKey.string(from: Date())
        let last = defaults.string(forKey: lastPlanKey)
        return last != key
    }

    private func markPlannedToday() {
        let now = Date()
        let key = DateFormatter.dayKey.string(from: now)
        defaults.set(key, forKey: lastPlanKey)
        defaults.set(now, forKey: lastPlanTimestampKey)
        lastManualPlanAt = now
    }
    
    func planForNext(days: Int = 14) async {
        guard canPlanToday() else {
            return
        }

        // YENİ: Dil kodunu en başta al
        let langCode = languageSettings.selectedLanguageCode

        var entries = (try? repo.load()) ?? []
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        
        // 1) İlk planlama tarihini al veya ayarla
        let firstPlanDate: Date
        if let storedTimeInterval = defaults.object(forKey: firstPlanDateKey) as? TimeInterval {
            // Eski kullanıcı: Kayıtlı tarihi al
            firstPlanDate = cal.startOfDay(for: Date(timeIntervalSince1970: storedTimeInterval))
        } else {
            // Yeni kullanıcı: Bu, fonksiyonun İLK ÇALIŞMASI.
            // İlk planlama tarihini "bugün" olarak kaydet.
            firstPlanDate = today
            defaults.set(today.timeIntervalSince1970, forKey: firstPlanDateKey)
            print("ScheduleService: Yeni kullanıcı. İlk planlama tarihi 'bugün' (\(today)) olarak ayarlandı.")
        }
        
        // 2) Geçmişi doldur: "ilk planlama" tarihinden "düne" kadar
        let daysBetween = cal.dateComponents([.day], from: firstPlanDate, to: today).day ?? 0
        
        if daysBetween > 0 { // Sadece 'firstPlanDate' geçmişteyse bu döngüye gir
            print("ScheduleService: \(daysBetween) günlük geçmiş kontrol ediliyor...")
            for i in 0..<daysBetween { // 'i' 0'dan başlar (ilk gün) 'daysBetween - 1'e (dün) kadar gider
                guard let day = cal.date(byAdding: .day, value: i, to: firstPlanDate) else { continue }
                
                // O gün için bir kayıt var mı?
                if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: day) }) {
                    // Kayıt var: Durumu .pending ve süresi dolmuşsa .missed yap
                    if entries[idx].status == .pending && now > entries[idx].expiresAt {
                        entries[idx].status = .missed
                    }
                } else {
                    // Kayıt yok: Bu, kullanıcının atladığı bir gün. .missed olarak oluştur.
                    let fakeScheduledAt = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
                    let fakeExpiresAt = cal.date(byAdding: .minute, value: 10, to: fakeScheduledAt) ?? day
                    
                    let missedEntry = DayEntry(
                        day: day,
                        scheduledAt: fakeScheduledAt,
                        expiresAt: fakeExpiresAt,
                        status: .missed
                    )
                    entries.append(missedEntry)
                }
            }
        }
        
        // 2) Bugün dâhil ileri günleri planla (her gün tek bildirim)
        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: i, to: today),
                  let fire = randomTime(on: day, startHour: fixedStartHour, endHour: fixedEndHour)
            else { continue }

            // BUGÜN ve rastgele saat geçmişse: o günü atla (spam’i önler)
            if cal.isDate(day, inSameDayAs: today), fire <= now { continue }

            let exp = expiry(for: fire)
            
            if let idx = entries.firstIndex(where: { cal.isDate($0.day, inSameDayAs: day) }) {
                if cal.isDate(day, inSameDayAs: today) || day > today {
                    entries[idx].scheduledAt = fire
                    entries[idx].expiresAt   = exp
                    entries[idx].status      = .pending
                    entries[idx].text        = nil
                    entries[idx].allowEarlyAnswer = false
                    
                    // GÜNCELLENDİ: langCode eklendi
                    try? await notifier.scheduleUniqueDaily(for: day, at: fire, langCode: langCode)
                }
            } else {
                entries.append(DayEntry(day: day, scheduledAt: fire, expiresAt: exp))
                // GÜNCELLENDİ: langCode eklendi
                try? await notifier.scheduleUniqueDaily(for: day, at: fire, langCode: langCode)
            }
        }

        try? repo.save(entries)
        RepositoryProvider.shared.entriesChanged.send()
        markPlannedToday()
    }
    
    func planAdminOneMinute() async {
        let langCode = languageSettings.selectedLanguageCode // YENİ
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
        // GÜNCELLENDİ: langCode eklendi
        try? await notifier.scheduleUniqueDaily(for: today, at: fire, langCode: langCode)
    }

    /// Belirli bir saate **tekil** bildirim planla (aynı güne eskileri iptal eder).
    func planTestNotification(at date: Date) async {
        let langCode = languageSettings.selectedLanguageCode // YENİ
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
        // GÜNCELLENDİ: langCode eklendi
        try? await notifier.scheduleUniqueDaily(for: day, at: date, langCode: langCode)
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
