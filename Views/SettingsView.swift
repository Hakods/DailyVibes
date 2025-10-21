//
//  SettingsView.swift
//  Daily Vibes
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var schedule: ScheduleService
    @EnvironmentObject var store: StoreService
    @StateObject private var vm = SettingsVM()
    @Environment(\.openURL) var openURL
    
    @StateObject private var paywallVM: PaywallVM
    
    @State private var exportURL: URL?
    @State private var tempURLToDelete: URL?
    @State private var isExportPreparing = false
    
    @State private var showExportToast = false
    
    @State private var showingExportErrorAlert = false
    @State private var exportErrorMessage = ""
    
    
    @State private var showAdminTools = false
    
    init() {
        _paywallVM = StateObject(wrappedValue: PaywallVM(store: RepositoryProvider.shared.store))
    }
    
    var body: some View {
        NavigationView {
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
                    if !store.isProUnlocked {
                        Section {
                            PaywallContent(vm: paywallVM) // Güncellenmiş Pro özellik listesiyle
                        } header: {
                            Text("✨ Daily Vibes Pro'ya Geçin")
                        } footer: {
                            Text("Satın alma Apple Kimliğinize bağlıdır. Aile Paylaşımı ve iade hakları Apple politikalarına tabidir.")
                                .font(.caption2)
                        }
                    } else {
                        Section {
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
                        }
                        header: {
                            Text("✨ Daily Vibes Pro")
                        }
                    }
                    
                    // MARK: - Planlama Bilgisi
                    Section {
                        PlanningInfoView()
#if DEBUG
                        if let lastPlan = schedule.lastManualPlanAt {
                            HStack {
                                Text("Son Otomatik Planlama:")
                                Spacer()
                                Text(vm.planTimestampDescription(for: lastPlan)) // Text içine alındı
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
#endif
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
                    
                    
                    // MARK: - ADMIN (DEBUG)
#if DEBUG
                    AdminToolsView(showAdminTools: $showAdminTools, vm: vm, schedule: schedule) // Sıfırlama butonu dahil
#endif
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Ayarlar")
            .onAppear {
                Task { @MainActor in
                    vm.authGranted = await RepositoryProvider.shared.notification.checkAuthStatus()
                    // Ürünleri ve durumu yükle (StoreService init içinde zaten yapılıyor olabilir,
                    // ama burada tekrar çağırmak genellikle zararsızdır)
                    if store.products.isEmpty { // Sadece ürünler boşsa yükle
                        await store.loadProducts()
                    }
                    // Durumu her seferinde güncellemek yerine belirli aksiyonlardan sonra güncellemek daha iyi olabilir,
                    // ama onAppear'da da kalabilir.
#if !DEBUG // Sadece Release modunda başlangıç durumunu kontrol et (StoreService'deki mantıkla uyumlu)
                    await store.updateSubscriptionStatus()
#endif
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
            
            // --- HATA ALERT MODIFIER ---
            .alert("Dışa Aktarma Hatası", isPresented: $showingExportErrorAlert) {
                Button("Tamam") { }
            } message: { Text(exportErrorMessage) }
        }
        .navigationViewStyle(.stack)
    }
    
    private func prepareAndExportToFile() {
        guard !isExportPreparing else { return }
        isExportPreparing = true
        
        Task { @MainActor in
            var tempURL: URL? = nil
            do {
                let all = try RepositoryProvider.shared.dayRepo.load()
                
                // 🔎 İSTENEN FİLTRE:
                // - Gelecek günler dahil olmasın
                // - Bugün ise ve ping saati HENÜZ gelmemişse dahil olmasın
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
                
                let csvString = entries.sorted { $0.day < $1.day }.toCSV()
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

// Paywall İçeriği (Güncellenmiş özellik listesiyle)
private struct PaywallContent: View {
    @ObservedObject var vm: PaywallVM
    @EnvironmentObject var store: StoreService
    
    var body: some View {
        VStack(spacing: 16) {
            // --- DAHA DA GELİŞMİŞ ÖZELLİK LİSTESİ ---
            VStack(alignment: .leading, spacing: 10) {
                FeatureItem(icon: "brain.head.profile.fill", text: "**Sınırsız AI Koçu Erişimi:** Günlük limit olmadan içgörüler alın.")
                FeatureItem(icon: "arrow.down.doc.fill", text: "**Veri Dışa Aktarma:** Tüm kayıtlarınızı CSV formatında yedekleyin.")
                FeatureItem(icon: "lock.fill", text: "**Uygulama Kilidi:** Face ID/Touch ID ile gizliliğinizi koruyun.") // (Yakında eklenebilir)
                FeatureItem(icon: "paintbrush.pointed.fill", text: "**Özel Temalar & İkonlar:** Uygulama görünümünü kişiselleştirin.") // (Yakında eklenebilir)
            }
            .padding(.bottom, 8)
            // --- ÖZELLİK LİSTESİ SONU ---
            
            Divider()
            
            // Ürün fiyatı ve satın alma butonu (Aynı)
            if let pro = store.products.first(where: { $0.id == "pro_monthly" }) { // Product ID kontrolü
                VStack(spacing: 12) {
                    Text("Aylık abonelik ile tüm bu Pro özelliklere ve gelecek yeniliklere erişin:")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        vm.buy()
                    } label: {
                        HStack {
                            if vm.isPurchasing { ProgressView().tint(.white) }
                            Text("Abone Ol – \(pro.displayPrice)")
                                .fontWeight(.semibold).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(vm.isPurchasing)
                    
                    Button("Satın alımı geri yükle") { vm.restore() }
                        .font(.caption).foregroundStyle(Theme.accent)
                }
                .padding(.top, 8)
            } else {
                HStack {
                    ProgressView()
                    Text("Ödeme bilgisi yükleniyor...")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical)
            }
            
            // Hata mesajı (Aynı)
            if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.caption).multilineTextAlignment(.center)
            }
        }
    }
}

// Paywall içindeki özellik maddesi (Aynı)
private struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 20, alignment: .center)
                .padding(.top, 1)
            Text(.init(text)) // Markdown
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
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
            Label("Ping saatlerini arada gözden geçir.", systemImage: "calendar.badge.clock")
        }
        .font(.caption)
        .foregroundStyle(Theme.textSec)
    }
}

// Hakkında Bölümü Linkleri (Aynı)
private struct AboutLink: View {
    let title: String
    let urlString: String
    @Environment(\.openURL) var openURL
    
    var body: some View {
        Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: urlString.starts(with: "mailto:") ? "envelope.fill" : "arrow.up.forward.app.fill")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
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


// Admin Araçları (Sıfırlama butonu dahil, değişiklik yok)
private struct AdminToolsView: View {
    @Binding var showAdminTools: Bool
    @ObservedObject var vm: SettingsVM
    @ObservedObject var schedule: ScheduleService
    @EnvironmentObject var store: StoreService // Store eklendi
    
    var body: some View {
        Section("🛠️ Admin Araçları (DEBUG)") {
            DisclosureGroup("Araçları Göster/Gizle", isExpanded: $showAdminTools) {
                VStack(alignment: .leading, spacing: 10) {
                    // 1 dk ping butonu
                    Button {
                        Task {
                            if !vm.authGranted { vm.authGranted = await RepositoryProvider.shared.notification.requestAuth() }
                            await schedule.planAdminOneMinute()
                            RepositoryProvider.shared.notification.dumpPending()
                        }
                    } label: { Label("1 dk sonra ping planla", systemImage: "bolt.fill") }
                        .buttonStyle(.bordered).tint(.orange)
                    
                    // 5 sn test butonu
                    Button {
                        Task {
                            if !vm.authGranted { vm.authGranted = await RepositoryProvider.shared.notification.requestAuth() }
                            await RepositoryProvider.shared.notification.scheduleIn(seconds: 5)
                            RepositoryProvider.shared.notification.dumpPending()
                        }
                    } label: { Label("5 sn sonra test bildirimi", systemImage: "paperplane.fill") }
                        .buttonStyle(.bordered).tint(.blue)
                    
                    Divider().padding(.vertical, 4)
                    
                    // Sıfırlama butonu
                    Button(role: .destructive) {
                        store.resetProStatusForDebug() // Fonksiyonu çağır
                        HapticsService.notification(.warning)
                    } label: { Label("Pro Aboneliğini Sıfırla (Debug)", systemImage: "arrow.counterclockwise.circle.fill") }
                        .buttonStyle(.bordered).tint(.purple)
                    
                    Divider().padding(.vertical, 4)
                    
                    // Purge butonu
                    Button(role: .destructive) {
                        Task { await RepositoryProvider.shared.notification.purgeAllAppPending() }
                    } label: { Label("Bekleyen bildirimleri temizle (purge)", systemImage: "trash") }
                        .buttonStyle(.bordered).tint(.red)
                }
                .padding(.top, 5)
            }
        }
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
