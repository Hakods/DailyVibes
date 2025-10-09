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

    func scheduleUniqueDaily(for day: Date, at fire: Date) async throws {
        let id = Notif.id(for: day)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Bugün nasılsın?"
        content.body  = "10 dakika içinde kısaca yaz."
        content.categoryIdentifier = Notif.categoryId

        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(req)
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
}
