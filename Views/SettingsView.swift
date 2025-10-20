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
    
    @State private var showAdminTools = false
    
    init() {
        _paywallVM = StateObject(wrappedValue: PaywallVM(store: RepositoryProvider.shared.store))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                Form {
                    // MARK: - Bildirim Ayarları
                    Section {
                        NotificationStatusView(authGranted: vm.authGranted) {
                            vm.requestNotifications()
                        }
                        
                        // Pro ise ping sayısı ayarını göster
                        if store.isProUnlocked {
                            PingFrequencyView(schedule: schedule)
                        }
                        
                    } header: {
                        Text("🔔 Günlük Ping Ayarları")
                    } footer: {
                        // GÜNCELLENDİ: Sabit saat aralığını belirt
                        Text("Ping'ler her gün **10:00 – 22:00** arasında rastgele bir saatte gönderilir.")
                    }
                    
                    // MARK: - Daily Vibes Pro
                    // GÜNCELLENDİ: Pro değilse doğrudan Paywall içeriğini göster
                    if !store.isProUnlocked {
                        Section {
                            // PaywallView içeriğini buraya entegre ediyoruz
                            PaywallContent(vm: paywallVM)
                        } header: {
                            Text("✨ Daily Vibes Pro'ya Geçin")
                        } footer: {
                            Text("Satın alma Apple Kimliğinize bağlıdır. Aile Paylaşımı ve iade hakları Apple politikalarına tabidir.")
                                .font(.caption2) // Biraz daha küçük font
                        }
                    } else {
                        // Pro ise basit bir durum göstergesi
                        Section {
                            ProActiveStatusView()
                        } header: {
                            Text("✨ Daily Vibes Pro")
                        }                    }
                    
                    // MARK: - Planlama Bilgisi (Sadece Bilgilendirme)
                    Section {
                        PlanningInfoView()
                        #if DEBUG
                        if let lastPlan = schedule.lastManualPlanAt {
                            HStack {
                                Text("Son Otomatik Planlama:")
                                Spacer()
                                Text(vm.planTimestampDescription(for: lastPlan))
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
                    
                    // MARK: - Hakkında ve Destek
//                    Section {
//                        AboutLink(title: "Gizlilik Politikası", urlString: "https://your-privacy-policy-url.com")
//                        AboutLink(title: "Kullanım Koşulları", urlString: "https://your-terms-url.com")
//                        AboutLink(title: "Destek & Geri Bildirim", urlString: "mailto:destek@dailyvibes.app")
//                        AppVersionView()
//                    } header: {
//                        Text("ℹ️ Uygulama Hakkında")
//                    }
                    
                    // MARK: - ADMIN (DEBUG)
#if DEBUG
                    // Bu kısım aynı kalabilir
                    AdminToolsView(showAdminTools: $showAdminTools, vm: vm, schedule: schedule)
#endif
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Ayarlar")
            // .sheet artık burada gerekli değil, paywall entegre edildi
            .onAppear {
                Task { @MainActor in
                    vm.authGranted = await RepositoryProvider.shared.notification.checkAuthStatus()
                    await store.loadProducts()
                    await store.updateSubscriptionStatus()
                    // Paywall için ürünleri yükle (eğer PaywallVM içinde yapılmıyorsa)
                    // await paywallVM.store.loadProducts() // PaywallVM'in init'inde zaten yapılıyor
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}


// MARK: - Yeni ve Güncellenmiş Alt Bileşenler

// Bildirim Durumu (Saat bilgisi kaldırıldı)
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

// Paywall İçeriği (PaywallView'dan uyarlandı)
private struct PaywallContent: View {
    @ObservedObject var vm: PaywallVM
    @EnvironmentObject var store: StoreService
    
    var body: some View {
        VStack(spacing: 16) {
            // Özellikleri listeleyelim
            VStack(alignment: .leading, spacing: 8) {
                FeatureItem(icon: "clock.arrow.2.circlepath", text: "Esnek zaman aralığı (min. 1 saat)")
                FeatureItem(icon: "arrow.up.message.fill", text: "Günde 3 defaya kadar ping")
                FeatureItem(icon: "chart.bar.xaxis", text: "Detaylı istatistikler (Yakında)")
                FeatureItem(icon: "arrow.down.doc.fill", text: "Veri dışa aktarma (Yakında)")
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // Ürün fiyatı ve satın alma butonu
            if let pro = store.products.first(where: { $0.id == "pro_monthly" }) {
                VStack(spacing: 12) {
                    Text("Aylık abonelik ile tüm Pro özelliklere erişin:")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button {
                        vm.buy()
                    } label: {
                        HStack {
                            if vm.isPurchasing {
                                ProgressView().tint(.white)
                            }
                            Text("Abone Ol – \(pro.displayPrice)")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(vm.isPurchasing)

                    Button("Satın alımı geri yükle") { vm.restore() }
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, 8)
            } else {
                HStack {
                    ProgressView()
                    Text("Ödeme bilgisi yükleniyor...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical)
            }

            
            // Hata mesajı
            if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.caption).multilineTextAlignment(.center)
            }
        }
    }
}

// Paywall içindeki özellik maddesi
private struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }
}

// Pro Aktif Durumu Göstergesi
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

// Planlama Bilgi View'ı (Butonsuz)
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

// PingFrequencyView (Pro için)
private struct PingFrequencyView: View {
    @ObservedObject var schedule: ScheduleService
    
    var body: some View {
        HStack {
            Text("Günlük Ping Sayısı")
            Spacer()
            Picker("Günlük Ping Sayısı", selection: $schedule.pingsPerDay) {
                ForEach(1...3, id: \.self) { Text("\($0)") }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 150) // Genişliği ayarla
        }
    }
}

// İpuçları Alanı
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

private struct AboutLink: View {
    let title: String
    let urlString: String
    @Environment(\.openURL) var openURL
    
    var body: some View {
        Button {
            if let url = URL(string: urlString) {
                openURL(url)
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: urlString.starts(with: "mailto:") ? "envelope.fill" : "arrow.up.forward.app.fill")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle()) // Tüm satırın tıklanabilir olması için
        }
        .buttonStyle(.plain) // Buton stilini düzelt
        .foregroundStyle(.primary) // Metin rengini ayarla
    }
}

// Uygulama Versiyonunu Gösteren View
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


// Admin Araçları (DEBUG)
private struct AdminToolsView: View {
    @Binding var showAdminTools: Bool
    @ObservedObject var vm: SettingsVM
    @ObservedObject var schedule: ScheduleService
    @EnvironmentObject var store: StoreService
    
    var body: some View {
        Section("🛠️ Admin Araçları (DEBUG)") {
            DisclosureGroup("Araçları Göster/Gizle", isExpanded: $showAdminTools) {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        Task {
                            if !vm.authGranted {
                                vm.authGranted = await RepositoryProvider.shared.notification.requestAuth()
                            }
                            await schedule.planAdminOneMinute()
                            RepositoryProvider.shared.notification.dumpPending()
                        }
                    } label: {
                        Label("1 dk sonra ping planla", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    Button {
                        Task {
                            if !vm.authGranted {
                                vm.authGranted = await RepositoryProvider.shared.notification.requestAuth()
                            }
                            await RepositoryProvider.shared.notification.scheduleIn(seconds: 5)
                            RepositoryProvider.shared.notification.dumpPending()
                        }
                    } label: {
                        Label("5 sn sonra test bildirimi", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Divider().padding(.vertical, 4)
                    
                    Button(role: .destructive) {
                        store.resetProStatusForDebug()
                        HapticsService.notification(.warning) // Farklı bir titreşim
                    } label: {
                        Label("Pro Aboneliğini Sıfırla (Debug)", systemImage: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple) // Farklı bir renk
                    
                    Divider().padding(.vertical, 4)
                    
                    Button(role: .destructive) {
                        Task { await RepositoryProvider.shared.notification.purgeAllAppPending() }
                    } label: {
                        Label("Bekleyen bildirimleri temizle (purge)", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.top, 5) // DisclosureGroup içeriği için biraz boşluk
            }
        }
    }
}

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
