//
//  MoreView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 3.11.2025.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        // Bu, "Daha Fazla" tab'ının kendisi olacak
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                // "Statistics" ve "Settings"e link veren bir liste
                Form {
                    Section {
                        NavigationLink {
                            StatsView()
                        } label: {
                            // "tab.stats" anahtarını kullan
                            Label(LocalizedStringKey("tab.stats"), systemImage: "chart.pie.fill")
                        }
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            // "tab.settings" anahtarını kullan
                            Label(LocalizedStringKey("tab.settings"), systemImage: "gearshape.fill")
                        }
                    }
                    .listRowBackground(Theme.card.opacity(0.8))
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            // Bu View'ın ana başlığı
            .navigationTitle(LocalizedStringKey("tab.more"))
        }
    }
}
