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
                        Label(LocalizedStringKey("tab.today"), systemImage: "sun.max.fill")
                    }
                SummaryView()
                    .tabItem {
                        Label(LocalizedStringKey("tab.summaries"), systemImage: "sparkles.rectangle.stack.fill")
                    }
                CoachView()
                    .tabItem {
                        Label(LocalizedStringKey("tab.coach"), systemImage: "brain.head.profile")
                    }
                HistoryView()
                    .tabItem {
                        Label(LocalizedStringKey("tab.history"), systemImage: "clock.fill")
                    }
                
                MoreView()
                    .tabItem {
                        Label(LocalizedStringKey("tab.more"), systemImage: "ellipsis")
                    }
            }
            .tint(Theme.secondary)
        }
    }
}
