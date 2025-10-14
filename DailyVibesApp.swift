//
//  DailyVibesApp.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

import SwiftUI
import CoreData // HATA GİDERİCİ: Bu satırı ekliyoruz.

@main
struct DailyVibesApp: App {
    // Core Data yöneticisini oluştur
    let persistenceController = PersistenceController.shared
    
    @StateObject private var store = StoreService()
    @StateObject private var schedule = ScheduleService()

    var body: some Scene {
        WindowGroup {
            RootView()
                // Core Data context'ini environment'a ekle
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(store)
                .environmentObject(schedule)
                .tint(Theme.accent)
                .background(Theme.bg)
                .preferredColorScheme(.light)
        }
    }
}
