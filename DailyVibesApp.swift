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
import FirebaseAppCheckInterop
import DeviceCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        AppCheck.setAppCheckProviderFactory(VibeMindAppCheckProviderFactory())
        
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
    @StateObject private var schedule: ScheduleService
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var languageSettings: LanguageSettings // Önce tanımla
    @State private var isDataReady: Bool = false
    
    init() {
        _store = StateObject(wrappedValue: RepositoryProvider.shared.store)
        
        // ÖNCE languageSettings oluşturulur
        let langSettings = LanguageSettings()
        _languageSettings = StateObject(wrappedValue: langSettings)
        
        // SONRA schedule oluşturulurken 'langSettings' içine verilir
        _schedule = StateObject(wrappedValue: ScheduleService(languageSettings: langSettings))
    }
    
    var body: some Scene {
        WindowGroup {
            if isDataReady {
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
                    }
                    else {
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
            else {
                ZStack {
                    AnimatedAuroraBackground()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.secondary)
                    }
                }
                .environmentObject(themeManager)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await schedule.planForNext(days: 14)
                    print("Uygulama aktif oldu: Gelecek 14 gün için planlama tamamlandı.")
                    
                    await MainActor.run {
                        isDataReady = true
                    }
                }
            }
        }
    }
}
