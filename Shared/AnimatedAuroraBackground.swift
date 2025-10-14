//
//  AnimatedAuroraBackground.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 7.10.2025.
//

import SwiftUI

struct AnimatedAuroraBackground: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var move = false
    
    var body: some View {
        ZStack {
            // Base soft gradient
            LinearGradient(
                colors: [
                    Color(hex: "#E0F7FA"),
                    Color(hex: "#F3E5F5"),
                    Color(hex: "#FFF8E1")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.9)
            .ignoresSafeArea()
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.currentColors.primary.opacity(0.45),
                            themeManager.currentColors.secondary.opacity(0.45),
                            themeManager.currentColors.tertiary.opacity(0.45)
                        ],
                        startPoint: move ? .bottomLeading : .topTrailing,
                        endPoint: move ? .topTrailing : .bottomLeading
                    )
                )
                .rotationEffect(.degrees(20))
                .blur(radius: 100)
                .opacity(0.8) // Biraz daha belirgin hale getirelim
                .scaleEffect(1.4)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: move)
                .onAppear { move.toggle() }
            // YENİ: Renkler değiştiğinde yumuşak bir geçiş animasyonu
                .animation(.easeInOut(duration: 2.0), value: themeManager.currentColors.primary)
            
            Rectangle()
                .fill(Color.black.opacity(0.02))
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }
}

extension View {
    /// İçerik zeminini şeffaf yapıp, kök arka planın görünmesini sağlar.
    func appBackground() -> some View {
        self
            .scrollContentBackground(.hidden)   // Form/List için iOS 16+
            .background(Color.clear)            // ScrollView/Form/List container’ı
    }
}
