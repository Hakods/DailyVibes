//
//  SettingsVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import Combine

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
    }

    func requestNotifications() {
        Task { @MainActor in
            authGranted = await RepositoryProvider.shared.notification.requestAuth()
        }
    }
    
    func planTimestampDescription(for date: Date) -> String {
        let absolute = absoluteFormatter.string(from: date)
        let relative = relativeFormatter.localizedString(for: date, relativeTo: Date())
        return "\(absolute) • \(relative)"
    }
}
