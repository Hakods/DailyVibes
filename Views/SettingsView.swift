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
    @State private var showPaywall = false
    @State private var showAdminTools = false   // DEBUG araçlarını aç/kapat

    var body: some View {
        ZStack {
            // 🌈 Modern arka plan
            AnimatedAuroraBackground()

            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - ÖZET
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.accent.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "bell.badge")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Günlük Ping")
                                        .font(.headline)
                                    HStack(spacing: 8) {
                                        Badge(text: vm.authGranted ? "Bildirim izni var" : "Bildirim izni yok",
                                              color: vm.authGranted ? Theme.good : Theme.bad)
                                        Badge(text: "\(schedule.startHour):00 – \(schedule.endHour):00",
                                              color: Theme.accent)
                                    }
                                }
                                Spacer()
                            }

                            if !vm.authGranted {
                                Button("İzin iste") { vm.requestNotifications() }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }

                    // MARK: - ZAMAN PENCERESİ
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("🕒")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Zaman Penceresi")
                                        .font(.headline)
                                    Text("\(schedule.startHour):00 – \(schedule.endHour):00 arası rastgele ping")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSec)
                                }
                                Spacer()
                            }

                            Stepper("Başlangıç: \(schedule.startHour):00",
                                    value: $schedule.startHour, in: 5...22)

                            Stepper("Bitiş: \(schedule.endHour):00",
                                    value: $schedule.endHour, in: 6...23)

                            if store.isProUnlocked {
                                Divider().padding(.vertical, 6)
                                HStack {
                                    Text("Günlük ping sayısı")
                                    Spacer()
                                    Picker("", selection: $schedule.pingsPerDay) {
                                        ForEach(1...3, id: \.self) { Text("\($0)") }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(maxWidth: 180)
                                }
                                Text("Pro ile günde birden fazla ping planlayabilirsin.")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSec)
                            }
                        }
                    }

                    // MARK: - PLANLAMA
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("📅")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Planlama")
                                        .font(.headline)
                                    Text("Bildirimler yerel olarak planlanır. Günde tek bildirim bırakılır.")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSec)
                                }
                                Spacer()
                            }
                            
                            Button {
                                Task { await RepositoryProvider.shared.notification.dumpPendingDetailed() }
                            } label: {
                                Label("Bekleyen bildirimleri yazdır", systemImage: "list.bullet.rectangle")
                            }


                            Button {
                                Task { await schedule.planForNext(days: 14) }
                            } label: {
                                Label("Önümüzdeki 14 Günü Planla", systemImage: "calendar.badge.plus")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!vm.authGranted)
                            .overlay(alignment: .bottomLeading) {
                                if !vm.authGranted {
                                    Text("Önce bildirim izni ver.")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.bad)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }

                    // MARK: - PRO
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Text("✨").font(.title2)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Daily Vibes Pro")
                                        .font(.headline)
                                    Text("Daha çok ping, daha esnek zaman penceresi ve yakında gelecek özel analizler.")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSec)

                                    if store.isProUnlocked {
                                        Badge(text: "Pro aktif", color: Theme.good)
                                    } else {
                                        if let pro = store.products.first(where: { $0.id == "pro_unlock" }) {
                                            Button("Pro'yu Satın Al – \(pro.displayPrice)") { showPaywall = true }
                                                .buttonStyle(PrimaryButtonStyle())
                                        } else {
                                            Button("Pro'yu Satın Al") { showPaywall = true }
                                                .buttonStyle(PrimaryButtonStyle())
                                        }

                                        Button("Satın alımı geri yükle") {
                                            Task { await store.restore() }
                                        }
                                        .foregroundStyle(Theme.accent)
                                        .font(.caption)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // MARK: - İPUÇLARI
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text("💡")
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("İpuçları")
                                        .font(.headline)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Label("Kısa yazılar yeterli – düzenli olmak önemli.", systemImage: "checkmark.circle")
                                        Label("Ping saatlerini haftada bir gözden geçir.", systemImage: "clock")
                                        Label("Bugün meşgulsen pingi admin’den 1 dk sonraya alıp hemen yaz.", systemImage: "bolt")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSec)
                                }
                                Spacer()
                            }
                        }
                    }

                    // MARK: - ADMIN (DEBUG)
                    #if DEBUG
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Admin Araçları (DEBUG)")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { showAdminTools.toggle() }
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .rotationEffect(.degrees(showAdminTools ? 180 : 0))
                                }
                                .buttonStyle(.plain)
                            }

                            if showAdminTools {
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
                                    .buttonStyle(PrimaryButtonStyle())

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

                                    Divider().padding(.vertical, 4)

                                    Button(role: .destructive) {
                                        Task { await RepositoryProvider.shared.notification.purgeAllAppPending() }
                                    } label: {
                                        Label("Bekleyen bildirimleri temizle (purge)", systemImage: "trash")
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    #endif
                }
                .padding(16)
            }
        }
        .navigationTitle("Ayarlar")
        .sheet(isPresented: $showPaywall) { PaywallView(vm: .init(store: store)) }
        .onAppear {
            Task { @MainActor in
                vm.authGranted = await RepositoryProvider.shared.notification.requestAuth()
            }
        }
    }
}

// MARK: - Küçük bileşenler

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
