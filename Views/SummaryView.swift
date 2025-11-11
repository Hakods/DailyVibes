//
//  SummaryView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 22.10.2025.
//


import SwiftUI

struct SummaryView: View {
    @StateObject private var vm: SummaryVM
    @EnvironmentObject var languageSettings: LanguageSettings
    
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
                            isCheckingInitial: vm.isCheckingInitialState,
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
                            isCheckingInitial: vm.isCheckingInitialState,
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
            .onAppear {
                vm.updateLanguage(langCode: languageSettings.selectedLanguageCode)
            }
            .onChange(of: languageSettings.selectedLanguageCode) {_, newLangCode in
                vm.updateLanguage(langCode: newLangCode)
            }
        }
    }
}

struct SummaryCard: View {
    let period: SummaryPeriod
    let title: String
    let summaryText: String
    let isLoading: Bool
    let isCheckingInitial: Bool // <-- YENİ
    let errorMessage: String?
    let isGenerateEnabled: Bool
    let generateAction: () -> Void
    let cancelAction: () -> Void
    
    private var isButtonDisabled: Bool {
        isLoading || isCheckingInitial || !isGenerateEnabled
    }
    
    private var buttonTextKey: String {
        if isLoading {
            return "Oluşturuluyor..."
        }
        if isCheckingInitial {
            return "Yükleniyor..."
        }
        return isGenerateEnabled ? "Şimdi Oluştur" : "Güncel" 
    }
    
    // Buton metni için LocalizedStringKey veya düz String kullan
    private var buttonLabel: Text {
        let key = buttonTextKey
        if key == "Oluşturuluyor..." || key == "Yükleniyor..." {
            return Text(key) // Bunlar dinamik durumlar
        }
        return Text(LocalizedStringKey(key)) // Bunlar statik metinler
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.title2.bold())
            
            // --- GÜNCELLENDİ: İlk yükleme durumunu da kontrol et ---
            if isLoading || isCheckingInitial {
                // Yüklenirken veya ilk kontrol yapılırken ProgressView göster
                HStack {
                    ProgressView()
                    Text(isLoading ? "Oluşturuluyor..." : "Kontrol ediliyor...")
                        .foregroundStyle(Theme.textSec)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical)
                
            } else if let error = errorMessage {
                Text(LocalizedStringKey("summary.error.prefix"), comment: "Error prefix")
                    .foregroundStyle(Theme.bad)
                + Text(" \(error)") // Hata mesajı VM'den localize olarak geliyor varsayalım
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
                Label {
                    buttonLabel // <-- GÜNCELLENDİ
                } icon: {
                    Image(systemName: isGenerateEnabled ? "wand.and.stars" : "checkmark.circle.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isButtonDisabled) // <-- GÜNCELLENDİ
            .padding(.top, 5)
            
            // 'isCheckingInitial' durumunda bu ipucunu gösterme
            if !isGenerateEnabled && !isLoading && !isCheckingInitial && errorMessage == nil {
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
        // Animasyonları tüm durumlara göre güncelle
        .animation(.default, value: isLoading)
        .animation(.default, value: isCheckingInitial) // <-- YENİ
        .animation(.default, value: summaryText)
        .animation(.default, value: isGenerateEnabled)
        .animation(.easeInOut(duration: 0.2), value: !isGenerateEnabled && !isLoading && !isCheckingInitial && errorMessage == nil)
    }
}
