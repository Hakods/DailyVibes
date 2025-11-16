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
        // Bu metinler aslında bildirim geldiğinde ve kullanıcı bildirime
        // uzun bastığında görünür. Bunların da localize olması iyi olur
        // ama şimdilik ana sorunu çözmek için böyle bırakabiliriz.
        // Asıl bildirim metni (title/body) DİNAMİK olarak ayarlanacak.
        let text = UNTextInputNotificationAction(
            identifier: Notif.actionText,
            title: NSLocalizedString("notification.action.reply", bundle: .main, comment: "Bildirimdeki cevaplama butonu"), // Örn: "Kısa not yaz"
            options: [],
            textInputButtonTitle: NSLocalizedString("notification.action.send", bundle: .main, comment: "Bildirimdeki gönderme butonu"), // Örn: "Gönder"
            textInputPlaceholder: NSLocalizedString("notification.action.placeholder", bundle: .main, comment: "Bildirimdeki metin alanı placeholder'ı") // Örn: "Bugün nasılsın?"
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
        content.title = NSLocalizedString("notification.title", comment: "Bildirim başlığı") // "system" gibi davranır
        content.body  = NSLocalizedString("notification.body", comment: "Bildirim içeriği") // "system" gibi davranır
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
    
    // GÜNCELLENMİŞ FONKSİYON
    func scheduleUniqueDaily(for day: Date, at fire: Date, langCode: String) async throws {
        let id = Notif.id(for: day)
        
        let center = UNUserNotificationCenter.current()
        let pending = await pendingRequests()
        let sameDayIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("mood-") && $0 == id }
        
        if !sameDayIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: sameDayIds)
        }
    
        let content = UNMutableNotificationContent()
        
        // --- YENİ DİL SEÇME MANTIĞI ---
        let titleKey = "notification.title"
        let bodyKey = "notification.body"
        
        if langCode == "system" {
            // "Sistem" seçiliyse, eski gibi yap (iOS karar versin)
            // NSLocalizedString, bundle parametresi olmadan çağrıldığında
            // ana bundle'ı (ve cihaz dilini) kullanır.
            content.title = NSLocalizedString(titleKey, comment: "Bildirim başlığı")
            content.body  = NSLocalizedString(bodyKey, comment: "Bildirim içeriği")
        } else {
            // "en" veya "tr" seçiliyse, o dile ait bundle'ı bul
            let bundle: Bundle
            if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
               let langBundle = Bundle(path: path) {
                bundle = langBundle
            } else {
                bundle = Bundle.main // Bulamazsa varsayılan
            }
            
            // Metni o bundle'dan (Localizable.xcstrings) çek
            content.title = NSLocalizedString(titleKey, bundle: bundle, comment: "Bildirim başlığı")
            content.body  = NSLocalizedString(bodyKey, bundle: bundle, comment: "Bildirim içeriği")
        }
        // --- YENİ DİL SEÇME MANTIĞI BİTTİ ---
        
        content.categoryIdentifier = Notif.categoryId
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(req)
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
}

extension NotificationService {
    func checkAuthStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
