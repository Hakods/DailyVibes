//
//  SettingsView.swift
//  Daily Vibes
//

import SwiftUI
import StoreKit
import UIKit

struct SettingsView: View {
    @EnvironmentObject var schedule: ScheduleService
    @EnvironmentObject var store: StoreService
    @EnvironmentObject var languageSettings: LanguageSettings
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.openURL) var openURL
    @Environment(\.requestReview) var requestReview
    
    @StateObject private var vm = SettingsVM()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    
    @State private var showPaywallSheet = false
    @State private var exportURL: URL?
    @State private var tempURLToDelete: URL?
    @State private var isExportPreparing = false
    @State private var showExportToast = false
    @State private var showingExportErrorAlert = false
    @State private var exportErrorMessage = ""
    
    var body: some View {
        ZStack {
            
            AnimatedAuroraBackground()
            
            if showExportToast {
                VStack {
                    Spacer()
                    Text("✅ Dışa aktarma tamamlandı!")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
                .animation(.easeInOut, value: showExportToast)
            }
            
            
            Form {
                // MARK: - Bildirim Ayarları
                Section {
                    NotificationStatusView(authGranted: vm.authGranted) {
                        vm.requestNotifications()
                    }
                    // Ping sayısı ayarı kaldırıldı.
                } header: {
                    Text("🔔 Günlük Ping Ayarları")
                } footer: {
                    Text("Ping'ler her gün **10:00 – 22:00** arasında rastgele bir saatte gönderilir.")
                }
                
                // MARK: - Daily Vibes Pro
                Section {
                    if store.isProUnlocked {
                        ProActiveStatusView()
                        Button {
                            prepareAndExportToFile()
                        } label: {
                            HStack {
                                if isExportPreparing {
                                    ProgressView().tint(.white)
                                    Text("Dışa aktarılıyor...").fontWeight(.semibold)
                                } else {
                                    Label("Verileri Dosyaya Aktar (CSV)", systemImage: "doc.badge.arrow.up.fill")
                                        .fontWeight(.semibold)
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: isExportPreparing)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isExportPreparing)
                        
                        Label {
                            Text("Kayıtların yalnızca cihazında saklanır, dışa aktarma manuel dosya kaydı yapar.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        } icon: {
                            Image(systemName: "lock.doc.fill")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                        
                    } else {
                        VStack(spacing: 15) {
                            Text("✨ Daily Vibes Pro'ya Geçin")
                                .font(.headline)
                            Text("Sınırsız AI Koçu erişimi, derinlemesine özetler, veri dışa aktarma ve daha fazlası için Pro'ya yükseltin.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSec)
                                .multilineTextAlignment(.center)
                            Button("Pro Özellikleri Gör ve Abone Ol") {
                                showPaywallSheet = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.vertical)
                    }
                } header: {
                    Text("✨ Daily Vibes Pro")
                } footer: {
                    Text("Satın alma Apple Kimliğinize bağlıdır. Aile Paylaşımı ve iade hakları Apple politikalarına tabidir.")
                        .font(.caption2)
                }
                
                // MARK: - Planlama Bilgisi
                Section {
                    PlanningInfoView()
                } header: {
                    Text("📅 Planlama")
                } footer: {
                    Text("Bildirimler her gün otomatik olarak planlanır.")
                }
                
                // MARK: - Yardımcı Bilgiler
                Section {
                    TipsView()
                } header: {
                    Text("💡 İpuçları")
                }
                
                Section {
                    Picker(LocalizedStringKey("settings.language.pickerLabel"), selection: $languageSettings.selectedLanguageCode) {
                        
                        Text(LocalizedStringKey("settings.language.systemDefault"))
                            .tag(LanguageCode.system.rawValue)
                        
                        Text("English")
                            .tag(LanguageCode.english.rawValue)
                        
                        Text("Türkçe")
                            .tag(LanguageCode.turkish.rawValue)
                        
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(LocalizedStringKey("settings.language.title"))
                }
                
                Section(LocalizedStringKey("settings.section.app")) {
                    
                    NavigationLink {
                        LegalTextView(content: .privacyPolicy)
                    } label: {
                        Label(LocalizedStringKey("legal.privacyPolicy.title"), systemImage: "lock.shield.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    
                    NavigationLink {
                        LegalTextView(content: .termsOfService)
                    } label: {
                        Label(LocalizedStringKey("legal.termsOfService.title"), systemImage: "doc.text.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    
                    AboutLink(
                        title: "settings.supportLink.title",
                        iconName: "envelope.fill",
                        urlString: "https://github.com/Hakods/DailyVibes-Support"
                    )
                    
                    Button {
                        requestReview()
                    } label: {
                        Label(LocalizedStringKey("settings.button.rateApp"), systemImage: "star.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label(LocalizedStringKey("settings.button.redoOnboarding"), systemImage: "arrow.circlepath")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .listRowBackground(Theme.card.opacity(0.8))
                
                Section {
                    AppVersionView()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Ayarlar")
        }
        .onAppear {
            Task { @MainActor in
                vm.authGranted = await RepositoryProvider.shared.notification.checkAuthStatus()
                if store.products.isEmpty {
                    await store.loadProducts()
                }
                await store.updateSubscriptionStatus()
            }
        }
        .sheet(item: $exportURL, onDismiss: {
            cleanupTemporaryFile(url: tempURLToDelete)
            tempURLToDelete = nil
            exportURL = nil
        }) { url in
            DocumentPicker(fileURLToExport: url)
                .ignoresSafeArea()
        }
        
        .alert("Dışa Aktarma Hatası", isPresented: $showingExportErrorAlert) {
            Button("Tamam") { }
        } message: { Text(exportErrorMessage) }
            .sheet(isPresented: $showPaywallSheet) {
                PaywallView(vm: PaywallVM(store: self.store))
                    .environmentObject(self.store)
                    .environmentObject(self.themeManager)
            }
    }
    
    private func prepareAndExportToFile() {
        guard !isExportPreparing else { return }
        isExportPreparing = true
        
        Task { @MainActor in
            var tempURL: URL? = nil
            do {
                let all = try RepositoryProvider.shared.dayRepo.load()
                
                let now = Date()
                let cal = Calendar.current
                let startOfToday = cal.startOfDay(for: now)
                
                let entries = all.filter { e in
                    // gelecekteki günler
                    if e.day > startOfToday { return false }
                    // bugün ve zamanı henüz gelmemişse
                    if cal.isDate(e.day, inSameDayAs: now), e.scheduledAt > now { return false }
                    // aksi halde dahil
                    return true
                }
                
                guard !entries.isEmpty else {
                    isExportPreparing = false
                    HapticsService.notification(.warning)
                    exportErrorMessage = "Dışa aktarılacak kayıt bulunamadı."
                    showingExportErrorAlert = true
                    return
                }
                
                let langCode = languageSettings.selectedLanguageCode
                let currentLocale: Locale
                let currentBundle: Bundle
                
                if langCode == "system" {
                    currentLocale = Locale.autoupdatingCurrent
                    currentBundle = .main
                } else {
                    currentLocale = Locale(identifier: langCode)
                    if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
                       let langBundle = Bundle(path: path) {
                        currentBundle = langBundle
                    } else {
                        currentBundle = .main
                    }
                }
                
                let csvString = entries.sorted { $0.day < $1.day }.toCSV(locale: currentLocale, bundle: currentBundle)
                guard let data = csvString.data(using: .utf8) else {
                    throw NSError(domain: "CSVEncoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "CSV UTF-8'e çevrilemedi"])
                }
                
                let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmm"
                let filename = "daily_vibes_export_\(df.string(from: Date())).csv"
                tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: tempURL!)
                
                HapticsService.notification(.success)
                showExportToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showExportToast = false }
                
                self.tempURLToDelete = tempURL
                self.exportURL = tempURL
                
            } catch {
                cleanupTemporaryFile(url: tempURL)
                exportErrorMessage = "Dışa aktarma sırasında hata: \(error.localizedDescription)"
                showingExportErrorAlert = true
                HapticsService.notification(.error)
            }
            isExportPreparing = false
        }
    }
    
    
    
    
    private func cleanupTemporaryFile(url: URL?) {
        guard let url = url else { return }
        DispatchQueue.global(qos: .background).async {
            do {
                try FileManager.default.removeItem(at: url)
                print("   🧹 Geçici dosya silindi: \(url.path)")
            } catch {
                print("   ⚠️ Geçici dosya silinirken hata: \(error)")
            }
        }
    }
    
}


// MARK: - Alt Bileşenler

// Bildirim Durumu (Değişiklik yok)
private struct NotificationStatusView: View {
    let authGranted: Bool
    var onRequest: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: authGranted ? "bell.badge.fill" : "bell.slash.fill")
                .font(.title3)
                .foregroundStyle(authGranted ? Theme.good : Theme.bad)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authGranted ? "Bildirimler Aktif" : "Bildirim İzni Gerekli")
                    .font(.headline)
                Text(authGranted ? "Ping almaya hazırsın!" : "Ping alabilmek için izin vermelisin.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSec)
            }
            Spacer()
            if !authGranted {
                Button("İzin Ver", action: onRequest)
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

// Pro Aktif Durumu Göstergesi (Aynı)
private struct ProActiveStatusView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Theme.good)
            Text("Pro özellikler aktif. Teşekkürler!")
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// Planlama Bilgi View'ı (Aynı)
private struct PlanningInfoView: View {
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(Theme.secondary)
                .frame(width: 30)
            Text("Bildirimleriniz her gün otomatik olarak planlanır ve rastgele bir saatte gönderilir.")
                .font(.caption)
                .foregroundStyle(Theme.textSec)
        }
        .padding(.vertical, 4)
    }
}

// İpuçları Alanı (Aynı)
private struct TipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Kısa ve düzenli yazmak en önemlisi.", systemImage: "pencil.line")
            Label("Ping saatlerini kaçırmamaya dikkat et.", systemImage: "calendar.badge.clock")
        }
        .font(.caption)
        .foregroundStyle(Theme.textSec)
    }
}

private struct AboutLink: View {
    let title: LocalizedStringKey
    let iconName: String
    let urlString: String
    @Environment(\.openURL) var openURL
    
    var body: some View {
        Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(Theme.accent)
                } icon: {
                    Image(systemName: iconName)
                        .foregroundStyle(Theme.accent)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
}
// Uygulama Versiyonu (Aynı)
private struct AppVersionView: View {
    var body: some View {
        HStack {
            Text("Uygulama Versiyonu")
            Spacer()
            Text(appVersion())
                .foregroundStyle(.secondary)
        }
    }
    
    private func appVersion() -> String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return "Bilinmiyor"
        }
        return "\(version) (\(build))"
    }
}

// Badge (Aynı)
private struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule(style: .continuous))
            .foregroundStyle(color)
    }
}
struct DocumentPicker: UIViewControllerRepresentable {
    // Sadece dışa aktarılacak dosyanın URL'ini alalım
    let fileURLToExport: URL
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // .exportToService modunda bu URL ile başlat
        // `asCopy: true` önemli, orijinal geçici dosyayı korur
        let controller = UIDocumentPickerViewController(forExporting: [fileURLToExport], asCopy: true)
        controller.delegate = context.coordinator
        print("   📄 DocumentPicker oluşturuldu (URL: \(fileURLToExport.path))")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        // Coordinator'a silinecek URL'i vermeye gerek yok, onDisappear'da hallediyoruz.
        Coordinator()
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        // parent referansına gerek kalmadı
        
        // DÜZELTME: urls parametresi [URL], opsiyonel değil
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Kaydetme işlemi başarılı oldu, seçilen URL'i loglayabiliriz
            if let savedURL = urls.first {
                print("   ✅ Dosya kaydedildi/seçildi: \(savedURL)")
            } else {
                print("   ℹ️ DocumentPicker tamamlandı ama URL dönmedi?") // Beklenmedik durum
            }
            // Geçici dosyayı silme işi artık View'ın onDisappear'ında
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("   ℹ️ DocumentPicker kullanıcı tarafından iptal edildi.")
            // Geçici dosyayı silme işi artık View'ın onDisappear'ında
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { self.absoluteString }
}
