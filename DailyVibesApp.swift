//
//  DailyVibesApp.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

import SwiftUI
import FirebaseCore
import CoreData
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    
    var providerFactory: AppCheckProviderFactory
    #if DEBUG
      providerFactory = AppCheckDebugProviderFactory()
      print("🔔 App Check: DEBUG modu aktif.")
    #else
      providerFactory = AppAttestProviderFactory()
      print("🔒 App Check: RELEASE (App Attest) modu aktif.")
    #endif
    
    AppCheck.setAppCheckProviderFactory(providerFactory)

    FirebaseApp.configure()
    
    return true
  }
}


@main
struct DailyVibesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    let persistenceController = PersistenceController.shared
    @StateObject private var store: StoreService
    @StateObject private var schedule = ScheduleService()
    @StateObject private var themeManager = ThemeManager()

    init() {
        _store = StateObject(wrappedValue: RepositoryProvider.shared.store)
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(store)
                    .environmentObject(schedule)
                    .environmentObject(themeManager)
                    .tint(Theme.accent)
                    .background(Theme.bg)
                    .preferredColorScheme(.light)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(RepositoryProvider.shared.notification)
                    .environmentObject(themeManager)
                    .tint(Theme.accent)
                    .background(Theme.bg)
                    .preferredColorScheme(.light)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
             if newPhase == .active && oldPhase != .active {
                 print("App became active")
             }
        }
    }
}
