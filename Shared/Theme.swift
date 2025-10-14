//
//  Theme.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//


//
//  Theme.swift
//  Daily Vibes
//

import SwiftUI

// MARK: - Renk Paleti ve Semantik Tonlar
struct Theme {
    // Çekirdek renkler (canlı ama yormayan)
    static var primary: Color   { Color(hex: "#7C3AED") }  // Electric Purple
    static var secondary: Color { Color(hex: "#06B6D4") }  // Cyan
    static var tertiary: Color  { Color(hex: "#F59E0B") }  // Amber (accent spot)
    
    // Durum renkleri
    static var good: Color { Color(hex: "#10B981") }   // Mint/Green
    static var warn: Color { Color(hex: "#F59E0B") }   // Amber
    static var bad:  Color { Color(hex: "#EF4444") }   // Red
    
    // Metin
    static var text: Color    { Color.primary }
    static var textSec: Color { Color.primary.opacity(0.65) }
    
    // Arkaplan (sistemle uyumlu)
    static var bg: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? .black : .systemGroupedBackground
        })
    }
    
    // Kart rengi (asıl görünümü glassCard verir; bu fallback)
    static var card: Color { Color.white.opacity(0.12) }
    
    // Gradyanlar
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [secondary, primary], startPoint: .leading, endPoint: .trailing)
    }
    static var successGradient: LinearGradient {
        LinearGradient(colors: [good, secondary], startPoint: .top, endPoint: .bottom)
    }
    
    static var softShadow: Color { .black.opacity(0.15) }
}

// MARK: - Cam Kart (Glass) Modifiyer
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Theme.softShadow, radius: 14, x: 0, y: 8)
    }
}

extension View {
    /// Kartları şık cam efektiyle göstermek için:
    /// `VStack { ... }.glassCard()`
    func glassCard() -> some View { modifier(GlassCard()) }
}

// MARK: - Buton Stilleri
struct PrimaryButtonStyle: ButtonStyle {
    // Butonun aktif olup olmadığını anlamak için Environment'ı kullanıyoruz.
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .padding(.vertical, 12).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                // Buton aktifse normal, devre dışıysa soluk bir gradient göster.
                Theme.accentGradient
                    .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .foregroundStyle(.white)
        // Devre dışıysa gölgeyi de azalt.
            .shadow(color: isEnabled ? Theme.secondary.opacity(0.35) : .clear, radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        // isEnabled durumuna göre animasyon ekleyerek geçişi yumuşat.
            .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

struct SubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .foregroundStyle(Theme.text)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .padding(.vertical, 12).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.bad.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .foregroundStyle(.white)
            .shadow(color: Theme.bad.opacity(0.35), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Animated Background (modern & sakin)
extension Theme {
    /// Soft, hareketli bir gradyan arkaplan.
    /// Kullanım: `ZStack { Theme.AnimatedBackground(); content }`
    struct AnimatedBackground: View {
        @State private var t: CGFloat = 0
        
        var body: some View {
            TimelineView(.animation) { _ in
                ZStack {
                    RadialGradient(
                        colors: [.clear, Theme.primary.opacity(0.45)],
                        center: .init(x: 0.2 + 0.1 * sin(t), y: 0.2 + 0.1 * cos(t)),
                        startRadius: 20,
                        endRadius: 520
                    )
                    RadialGradient(
                        colors: [.clear, Theme.secondary.opacity(0.45)],
                        center: .init(x: 0.8 + 0.1 * cos(t*0.8), y: 0.3 + 0.1 * sin(t*0.8)),
                        startRadius: 20,
                        endRadius: 520
                    )
                    RadialGradient(
                        colors: [.clear, Theme.tertiary.opacity(0.35)],
                        center: .init(x: 0.5 + 0.12 * sin(t*0.6), y: 0.8 + 0.08 * cos(t*0.6)),
                        startRadius: 10,
                        endRadius: 480
                    )
                }
                .background(Theme.bg)
                .blur(radius: 90)
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        t = .pi * 2
                    }
                }
            }
        }
    }
}

// MARK: - Hex → Color helper
extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var i: UInt64 = 0; Scanner(string: s).scanHexInt64(&i)
        let a, r, g, b: UInt64
        switch s.count {
        case 3: (a, r, g, b) = (255, (i >> 8) * 17, (i >> 4 & 0xF) * 17, (i & 0xF) * 17)
        case 6: (a, r, g, b) = (255, i >> 16, i >> 8 & 0xFF, i & 0xFF)
        case 8: (a, r, g, b) = (i >> 24, i >> 16 & 0xFF, i >> 8 & 0xFF, i & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// Eski kodla uyumluluk için "accent" takma adı
extension Theme {
    static var accent: Color { secondary }
}
