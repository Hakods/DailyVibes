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

    func requestNotifications() {
        Task { @MainActor in
            authGranted = await RepositoryProvider.shared.notification.requestAuth()
        }
    }
}
