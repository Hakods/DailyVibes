//
//  PaywallView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject var vm: PaywallVM
    @EnvironmentObject var store: StoreService
    @EnvironmentObject var languageSettings: LanguageSettings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeaderView()
                    FeaturesView()
                    SubscriptionOptionsView(vm: vm)
                    RestoreButtonView(vm: vm)
                    ErrorTextView(vm: vm)
                    TermsTextView()
                }
                .padding(.horizontal)
                .padding(.bottom) // ScrollView alt boşluğu
            }
            .background(AnimatedAuroraBackground().opacity(0.3)) // Hafif arka plan
            .navigationTitle(LocalizedStringKey("paywall.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("button.close")) { dismiss() }
                }
            }
            .overlay {
                if !store.isReady || vm.isPurchasing {
                    ProgressView(LocalizedStringKey("Yükleniyor..."))
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .onAppear {
                vm.updateLanguage(langCode: languageSettings.selectedLanguageCode)
            }
            .onChange(of: languageSettings.selectedLanguageCode) { _, newLangCode in
                vm.updateLanguage(langCode: newLangCode)
            }
        }
    }
}

// MARK: - Alt Bileşenler

private struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(Theme.accentGradient)
            Text(LocalizedStringKey("Potansiyelini Açığa Çıkar"))
                .font(.title2.bold())
            Text(LocalizedStringKey("Daily Vibes Pro ile sınırsız içgörüye, özel analizlere ve daha fazlasına erişin."))
                .font(.subheadline)
                .foregroundStyle(Theme.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top)
    }
}

private struct FeaturesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureItem(icon: "brain.head.profile.fill", textKey: "paywall.feature.ai")
            FeatureItem(icon: "arrow.down.doc.fill", textKey: "paywall.feature.export")
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct FeatureItem: View {
    let icon: String
    let textKey: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 20, alignment: .center)
                .padding(.top, 1)
            Text(LocalizedStringKey(textKey))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}



private struct SubscriptionOptionsView: View {
    @ObservedObject var vm: PaywallVM
    @EnvironmentObject var store: StoreService
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(store.products) { product in
                SubscriptionButton(product: product, vm: vm)
            }
        }
    }
}

private struct SubscriptionButton: View {
    let product: Product
    @ObservedObject var vm: PaywallVM
    
    var isYearly: Bool { product.id == "pro_yearly" }
    
    private var fallbackDescriptionKey: String {
        isYearly ? "paywall.product.year.fallback" : "paywall.product.month.fallback"
    }
    
    var body: some View {
        Button {
            vm.buyProduct(product)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    
                    if product.description.isEmpty {
                        Text(LocalizedStringKey(fallbackDescriptionKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline.bold())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isYearly ? Theme.accent : Color.clear, lineWidth: 2)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isYearly {
                    Text(LocalizedStringKey("İndirimli!"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .offset(x: -10, y: -10)
                }
            }
        }
        .buttonStyle(.plain) // İçerideki stiller çalışsın diye
        .disabled(vm.isPurchasing) // Satın alma sırasında pasif yap
    }
}


private struct RestoreButtonView: View {
    @ObservedObject var vm: PaywallVM
    var body: some View {
        Button(LocalizedStringKey("Satın Alımları Geri Yükle")) { vm.restore() }
            .font(.footnote)
            .tint(Theme.accent)
            .disabled(vm.isPurchasing)
    }
}

private struct ErrorTextView: View {
    @ObservedObject var vm: PaywallVM
    var body: some View {
        if let err = vm.errorMessage {
            Text(err)
                .foregroundStyle(.red)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

private struct TermsTextView: View {
    
    let privacyPolicyURL = "https://github.com/Hakods/VibeMind-Support"
    let termsOfUseURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                if let url = URL(string: privacyPolicyURL) {
                    Link("Gizlilik Politikası", destination: url)
                }
                
                Text("|")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                
                if let url = URL(string: termsOfUseURL) {
                    Link("Kullanım Şartları", destination: url)
                }
            }
            .font(.caption.weight(.medium))
            .tint(Theme.accent)
            Text(LocalizedStringKey("Satın alma Apple Kimliğinize bağlıdır. Aile Paylaşımı ve iade hakları Apple politikalarına tabidir. Abonelik, iptal edilmediği sürece otomatik olarak yenilenir."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
}
