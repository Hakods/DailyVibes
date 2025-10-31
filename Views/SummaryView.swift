//
//  SummaryView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 22.10.2025.
//


import SwiftUI

struct SummaryView: View {
    @StateObject private var vm: SummaryVM

    init() {
        _vm = StateObject(wrappedValue: SummaryVM())
    }

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SummaryCard(
                            period: .week,
                            title: "summary.weekly.title",
                            summaryText: vm.weeklySummary,
                            isLoading: vm.isLoadingWeekly,
                            errorMessage: vm.errorMessage,
                            isGenerateEnabled: vm.canGenerateWeeklySummary,
                            generateAction: { vm.generateSummary(for: .week) },
                            cancelAction: { vm.cancel() }
                        )

                        SummaryCard(
                            period: .month,
                            title: "summary.monthly.title",
                            summaryText: vm.monthlySummary,
                            isLoading: vm.isLoadingMonthly,
                            errorMessage: vm.errorMessage,
                            isGenerateEnabled: vm.canGenerateMonthlySummary,
                            generateAction: { vm.generateSummary(for: .month) },
                            cancelAction: { vm.cancel() }
                        )
                    }
                    .padding()
                }
                .appBackground()
            }
            .navigationTitle(LocalizedStringKey("summary.navigation.title"))
        }
    }
}

struct SummaryCard: View {
    let period: SummaryPeriod
    let title: String
    let summaryText: String
    let isLoading: Bool
    let errorMessage: String?
    let isGenerateEnabled: Bool
    let generateAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.title2.bold())

            if isLoading {
            } else if let error = errorMessage {
                Text("summary.error.prefix \(error)")
                    .foregroundStyle(Theme.bad)
            } else if summaryText.isEmpty {
                Text(isGenerateEnabled ? LocalizedStringKey("summary.empty.canGenerate") : LocalizedStringKey("summary.empty.cannotGenerate"))
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

            if !isGenerateEnabled && !isLoading && errorMessage == nil {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle")
                    Text(period == .week ? "Yeni özet her Pazartesi aktif olur." : "Yeni özet her ayın 1'inde aktif olur.")
                }
                .font(.caption)
                .foregroundStyle(Theme.textSec)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.default, value: isLoading)
        .animation(.default, value: summaryText)
        .animation(.default, value: isGenerateEnabled)
        .animation(.easeInOut(duration: 0.2), value: !isGenerateEnabled && !isLoading && errorMessage == nil)
    }
}
