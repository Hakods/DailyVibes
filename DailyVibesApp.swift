//
//  DailyVibesApp.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

import SwiftUI
import CoreData

@main
struct DailyVibesApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var store = StoreService()
    @StateObject private var schedule = ScheduleService()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(store)
                .environmentObject(schedule)
                .environmentObject(themeManager)
                .tint(Theme.accent)
                .background(Theme.bg)
                .preferredColorScheme(.light)
        }
    }
}
