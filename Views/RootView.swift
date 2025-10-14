//
//  RootView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            AnimatedAuroraBackground()
            
            TabView {
                TodayView()
                    .tabItem {
                        Label("Bugün", systemImage: "sun.max.fill")
                    }
                HistoryView()
                    .tabItem {
                        Label("Geçmiş", systemImage: "clock.fill")
                    }
                
                StatsView()
                    .tabItem {
                        Label("İstatistikler", systemImage: "chart.pie.fill")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Ayarlar", systemImage: "gearshape.fill")
                    }
            }
            .tint(Theme.secondary)
        }
    }
}
