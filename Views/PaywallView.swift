//
//  PaywallView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    // ViewModel'i dışarıdan alacağız veya burada oluşturacağız
    @StateObject var vm: PaywallVM
    @EnvironmentObject var store: StoreService // Store'a erişim gerekebilir
    @Environment(\.dismiss) var dismiss // Sheet'i kapatmak için
    
    var body: some View {
        NavigationView { // Sheet içinde başlık ve kapatma butonu için
            ScrollView {
                VStack(spacing: 20) {
                    HeaderView()
                    FeaturesView()
                    SubscriptionOptionsView(vm: vm) // Seçenekleri gösteren alt view
                    RestoreButtonView(vm: vm)
                    ErrorTextView(vm: vm)
                    TermsTextView()
                }
                .padding(.horizontal)
                .padding(.bottom) // ScrollView alt boşluğu
            }
            .background(AnimatedAuroraBackground().opacity(0.3)) // Hafif arka plan
            .navigationTitle("✨ Daily Vibes Pro ✨")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
            // Ürünler yüklenirken veya satın alma sırasında overlay gösterebiliriz
            .overlay {
                if store.products.isEmpty || vm.isPurchasing {
                    ProgressView("Yükleniyor...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// MARK: - Alt Bileşenler

private struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles") // Veya özel bir Pro ikonu
                .font(.system(size: 50))
                .foregroundStyle(Theme.accentGradient)
            Text("Potansiyelini Açığa Çıkar")
                .font(.title2.bold())
            Text("Daily Vibes Pro ile sınırsız içgörüye, özel analizlere ve daha fazlasına erişin.")
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
            FeatureItem(icon: "brain.head.profile.fill", text: "**Sınırsız AI Koçu Erişimi:** Günlük limit olmadan içgörüler alın.")
            FeatureItem(icon: "chart.line.uptrend.xyaxis.circle.fill", text: "**Derinlemesine Özetler:** AI destekli haftalık ve aylık analizler.") // Yeni ekledik
            FeatureItem(icon: "arrow.down.doc.fill", text: "**Veri Dışa Aktarma:** Tüm kayıtlarınızı CSV formatında yedekleyin.")
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }
}

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



private struct SubscriptionOptionsView: View {
    @ObservedObject var vm: PaywallVM
    @EnvironmentObject var store: StoreService // Ürünlere erişmek için
    
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
    
    var body: some View {
        Button {
            vm.buyProduct(product)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description.isEmpty ? (isYearly ? "Tüm yıl boyunca Pro erişim" : "Aylık Pro erişim") : product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline.bold())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial) // Veya Theme.card
                    .overlay(
                        // Yıllık planı vurgulamak için
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isYearly ? Theme.accent : Color.clear, lineWidth: 2)
                    )
            )
            .overlay(alignment: .topTrailing) {
                // Yıllık planda indirim etiketi
                if isYearly {
                    // İndirimi hesapla (StoreService'te hesaplanıp Product'a eklenebilir veya burada yapılabilir)
                    // Şimdilik sadece bir etiket koyalım
                    Text("İndirimli!")
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
        Button("Satın Alımları Geri Yükle") { vm.restore() }
            .font(.footnote)
            .tint(Theme.accent) // Buton rengi
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
    var body: some View {
        Text("Satın alma Apple Kimliğinize bağlıdır. Aile Paylaşımı ve iade hakları Apple politikalarına tabidir. Abonelik, iptal edilmediği sürece otomatik olarak yenilenir.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}
