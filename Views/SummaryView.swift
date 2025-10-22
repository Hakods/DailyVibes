//
//  SummaryView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 22.10.2025.
//


import SwiftUI

struct SummaryView: View {
    @StateObject private var vm: SummaryVM

    // ViewModel'i init içinde oluştur
    init() {
        _vm = StateObject(wrappedValue: SummaryVM())
    }

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Haftalık Özet Kartı
                        SummaryCard(
                            title: "Haftalık Özetin",
                            summaryText: vm.weeklySummary,
                            isLoading: vm.isLoadingWeekly,
                            errorMessage: vm.errorMessage,
                            // DÜZELTME: self.vm deneyelim
                            isGenerateEnabled: self.vm.canGenerateWeeklySummary,
                            generateAction: { self.vm.generateSummary(for: .week) }, // self ekleyelim
                            cancelAction: { self.vm.cancel() } // self ekleyelim
                        )

                        // Aylık Özet Kartı
                        SummaryCard(
                            title: "Aylık Özetin",
                            summaryText: vm.monthlySummary,
                            isLoading: vm.isLoadingMonthly,
                            errorMessage: vm.errorMessage,
                            // DÜZELTME: self.vm deneyelim
                            isGenerateEnabled: self.vm.canGenerateMonthlySummary,
                            generateAction: { self.vm.generateSummary(for: .month) }, // self ekleyelim
                            cancelAction: { self.vm.cancel() } // self ekleyelim
                        )
                    }
                    .padding()
                }
                .appBackground()
            }
            .navigationTitle("Özetlerin")
        }
    }
}

struct SummaryCard: View {
    let title: String
    let summaryText: String
    let isLoading: Bool
    let errorMessage: String?
    let isGenerateEnabled: Bool
    let generateAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())

            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 5)
                    Text("Özet oluşturuluyor...")
                        .foregroundStyle(Theme.textSec)
                    Spacer()
                    Button("İptal", role: .destructive, action: cancelAction)
                }
            } else if let error = errorMessage {
                Text("Hata: \(error)")
                    .foregroundStyle(Theme.bad)
            } else if summaryText.isEmpty {
                Text(isGenerateEnabled ? "Henüz bir özet oluşturulmadı. Oluşturmak için butona dokun." : "Bu dönem için özet zaten oluşturulmuş veya veri yok.")
                    .foregroundStyle(Theme.textSec)
            } else {
                Text(summaryText)
                    .lineSpacing(5)
            }

            Button {
                generateAction()
            } label: {
                Label(isLoading ? "Oluşturuluyor..." : (isGenerateEnabled ? "Şimdi Oluştur" : "Güncel"),
                      systemImage: isGenerateEnabled ? "wand.and.stars" : "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || !isGenerateEnabled)
            .padding(.top, 5)

        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.default, value: isLoading)
        .animation(.default, value: summaryText)
        .animation(.default, value: isGenerateEnabled)
    }
}
