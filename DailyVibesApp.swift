//
//  DailyVibesApp.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

// Dosya: Daily Vibes/DailyVibesApp.swift
// SENİN KODUNA GÖRE GÜNCELLENMİŞ HALİ

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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // --- ScenePhase EKSİKTİ, EKLEYELİM ---
    @Environment(\.scenePhase) var scenePhase
    // --- ScenePhase SON ---

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    let persistenceController = PersistenceController.shared
    @StateObject private var store: StoreService
    @StateObject private var schedule = ScheduleService()
    // themeManager burada oluşturuluyor
    @StateObject private var themeManager = ThemeManager()

    init() {
        _store = StateObject(wrappedValue: RepositoryProvider.shared.store)
        // --- GEÇİCİ TEST KODU ---
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        print("DEBUG: Onboarding flag reset to false.")
        // --- GEÇİCİ TEST KODU SONU ---
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(store)
                    .environmentObject(schedule)
                    .environmentObject(themeManager) // RootView için zaten vardı
                    .tint(Theme.accent)
                    .background(Theme.bg)
                    .preferredColorScheme(.light)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(RepositoryProvider.shared.notification)
                    // --- BURAYA EKLE ---
                    .environmentObject(themeManager)
                    // --- EKLEME SONU ---
                    .tint(Theme.accent)
                    .background(Theme.bg)
                    .preferredColorScheme(.light)
            }
        }
         // --- ScenePhase onChange EKSİKTİ, EKLEYELİM ---
         // (ReviewHandler kullanacaksan bu bloğu aktif et)
        .onChange(of: scenePhase) { oldPhase, newPhase in
             if newPhase == .active && oldPhase != .active {
                 // ReviewHandler.shared.appLaunched() // Değerlendirme isteme için
                 print("App became active") // Test için log
             }
        }
         // --- onChange SONU ---
    }
}
