//
//  DailyVibesApp.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

import SwiftUI

@main
struct DailyVibesApp: App {
    @StateObject private var store = StoreService()
    @StateObject private var schedule = ScheduleService()

    var body: some Scene {
        WindowGroup {
            RootView() // Uygulamanın ana ekranı
                .environmentObject(store)
                .environmentObject(schedule)
                .tint(Theme.accent)
                .background(Theme.bg)
                .preferredColorScheme(.light)
        }
    }
}
