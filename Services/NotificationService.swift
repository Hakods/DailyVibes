//
//  NotificationService.swift
//  Daily Vibes
//

import Foundation
import UserNotifications
import Combine

enum Notif {
    static let categoryId = "MOOD_INPUT"
    static let actionText = "MOOD_TEXT_INPUT"
    
    /// Gün bazlı tekil ID (örn: mood-20251006)
    static func id(for day: Date) -> String {
        "mood-\(DateFormatter.dayKey.string(from: day))"
    }
}

final class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Auth & Category
    
    func requestAuth() async -> Bool {
        do {
            let ok = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if ok { configureCategories() }
            return ok
        } catch {
            return false
        }
    }
    
    func configureCategories() {
        let text = UNTextInputNotificationAction(
            identifier: Notif.actionText,
            title: "Kısa not yaz",
            options: [],
            textInputButtonTitle: "Gönder",
            textInputPlaceholder: "Bugün nasılsın?"
        )
        
        let cat = UNNotificationCategory(
            identifier: Notif.categoryId,
            actions: [text],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }
    
    // MARK: - Scheduling
    
    /// Serbest ID ile planla (gerekirse)
    func schedule(on date: Date, id: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Bugün nasılsın?"
        content.body  = "10 dakika içinde kısaca yaz."
        content.categoryIdentifier = Notif.categoryId
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(req)
    }
    
    /// Hızlı test: N sn sonra
    func scheduleIn(seconds: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = "Test bildirimi"
        content.body  = "Bu bir test. Bildirimler çalışıyor ✅"
        content.categoryIdentifier = Notif.categoryId
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let id = "test-\(Int(Date().timeIntervalSince1970))"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }
    
    // MARK: - DEBUG log helper
#if DEBUG
    private func dbg(_ items: Any..., fn: String = #function) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        print("🔔[\(stamp)] \(fn):", items.map { "\($0)" }.joined(separator: " "))
    }
#endif
    
    func scheduleUniqueDaily(for day: Date, at fire: Date) async throws {
        let id = Notif.id(for: day)
        
        // 1) Aynı güne ait TÜM eski mood- isteklerini temizle (güçlü tekilleştirme)
        let center = UNUserNotificationCenter.current()
        let pending = await pendingRequests()
        let sameDayIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("mood-") && $0 == id }
        
        if !sameDayIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: sameDayIds)
#if DEBUG
            dbg("removed \(sameDayIds.count) pending for", id)
#endif
        }
        
        // 2) Yeniyi oluştur
        let content = UNMutableNotificationContent()
        content.title = "Bugün nasılsın?"
        content.body  = "10 dakika içinde kısaca yaz."
        content.categoryIdentifier = Notif.categoryId
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(req)
        
#if DEBUG
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        dbg("scheduled", id, "→", df.string(from: fire), "(comps:", comps, ")")
        let after = await pendingRequests().filter { $0.identifier.hasPrefix("mood-") }
        dbg("total mood- pending:", after.count)
#endif
    }
    
    
    // MARK: - Debug / Helpers
    
    func dumpPending() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            print("Pending count:", reqs.count)
            for r in reqs { print("•", r.identifier) }
        }
    }
    
    func removePending(with identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().getPendingNotificationRequests { cont.resume(returning: $0) }
        }
    }
    
    /// Belirli prefix’teki (mood-/test-/admin-) bekleyenleri temizle
    func removePending(withPrefix prefix: String) async {
        let reqs = await pendingRequests()
        let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ids.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
    
    /// Uygulamanın ürettiği tüm bekleyenleri temizle
    func purgeAllAppPending() async {
        await removePending(withPrefix: "mood-")
        await removePending(withPrefix: "test-")
        await removePending(withPrefix: "admin-")
    }

    @MainActor
    func dumpPendingDetailed() async {
        let reqs = await pendingRequests()
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        print("🔔 Pending (\(reqs.count)) --------------------------")
        for r in reqs {
            let when: String = {
                if let t = r.trigger as? UNCalendarNotificationTrigger,
                   let d = cal.date(from: t.dateComponents) {
                    return df.string(from: d)
                } else if let t = r.trigger as? UNTimeIntervalNotificationTrigger {
                    return "in \(Int(t.timeInterval))s"
                } else {
                    return "unknown"
                }
            }()
            print("• id=\(r.identifier) | when=\(when) | title=\(r.content.title)")
        }
        print("-----------------------------------------------------")
    }

    
#if DEBUG
    /// Bekleyen bildirimleri okunaklı şekilde döker.
    func dumpAllAppPendingPretty() async {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        let reqs = await pendingRequests()
        let sorted = reqs.sorted { a, b in
            let ta = (a.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            let tb = (b.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            switch (ta, tb) {
            case let (a?, b?): return a < b
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return a.identifier < b.identifier
            }
        }
        print("====== PENDING (\(sorted.count)) ======")
        for r in sorted {
            let when = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            print("• \(r.identifier) → \(when.map(df.string(from:)) ?? "-")")
        }
        print("===============================")
    }
#endif
}
