//
//  SettingsVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import Combine
import UIKit

@MainActor
final class SettingsVM: ObservableObject {
    @Published var authGranted: Bool = false
    
    private let relativeFormatter: RelativeDateTimeFormatter
    private let absoluteFormatter: DateFormatter
    
    init() {
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "tr_TR")
        rel.unitsStyle = .full
        self.relativeFormatter = rel
        
        let abs = DateFormatter()
        abs.locale = Locale(identifier: "tr_TR")
        abs.dateStyle = .medium
        abs.timeStyle = .short
        self.absoluteFormatter = abs
        
        Task {
            await checkAuthStatus()
        }
    }

    func checkAuthStatus() async {
        self.authGranted = await RepositoryProvider.shared.notification.checkAuthStatus()
    }
    
    func requestNotifications() {
        Task { @MainActor in
            let currentStatus = await UNUserNotificationCenter.current().notificationSettings()
            
            if currentStatus.authorizationStatus == .denied {
                print("İzin daha önce reddedilmiş, Ayarlar'a yönlendiriliyor...")
                if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(appSettingsURL)
                }
            } else if currentStatus.authorizationStatus == .notDetermined {
                print("İzin isteniyor...")
                let granted = await RepositoryProvider.shared.notification.requestAuth()
                self.authGranted = granted
            } else if currentStatus.authorizationStatus == .authorized {
                print("İzin zaten verilmiş.")
                self.authGranted = true
            }
        }
    }
    
    func planTimestampDescription(for date: Date) -> String {
        let absolute = absoluteFormatter.string(from: date)
        let relative = relativeFormatter.localizedString(for: date, relativeTo: Date())
        return "\(absolute) • \(relative)"
    }
}
