//
//  DailyVibesApp.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

import SwiftUI
import FirebaseCore
import CoreData

// Firebase'i başlatmak için en doğru yöntem olan "uygulama delegesi".
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}


@main
struct DailyVibesApp: App {
    // YENİ: Uygulama delegesini SwiftUI yaşam döngüsüne bağlıyoruz.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    
    let persistenceController = PersistenceController.shared
    @StateObject private var store: StoreService
    @StateObject private var schedule = ScheduleService()
    @StateObject private var themeManager = ThemeManager() // Bu da eksikti, ekledim.
    
    init() {
        _store = StateObject(wrappedValue: RepositoryProvider.shared.store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(store)
                .environmentObject(schedule)
                .environmentObject(themeManager) // Bu da eksikti, ekledim.
                .tint(Theme.accent)
                .background(Theme.bg)
                .preferredColorScheme(.light)
        }
    }
}
