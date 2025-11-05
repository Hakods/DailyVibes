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
    @StateObject private var languageSettings = LanguageSettings()
    
    init() {
        _store = StateObject(wrappedValue: RepositoryProvider.shared.store)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(store)
                        .environmentObject(schedule)
                        .environmentObject(themeManager)
                        .environmentObject(languageSettings)
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
            .environment(\.locale, languageSettings.computedLocale ?? Locale.autoupdatingCurrent)
            .id(languageSettings.selectedLanguageCode)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            
            if newPhase == .active {
                Task {
                    await schedule.planForNext(days: 14)
                    print("Uygulama aktif oldu: Gelecek 14 gün için planlama kontrol edildi.")
                }
            }
        }
    }
}
