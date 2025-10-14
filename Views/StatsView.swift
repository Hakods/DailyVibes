//
//  StatsView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 14.10.2025.
//


import SwiftUI
import Charts // Apple'ın grafik kütüphanesini import ediyoruz

struct StatsView: View {
    @StateObject private var vm = StatsVM()

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Genel Bakış Kartı
                        OverviewCard(totalAnswered: vm.totalAnswered, averageScore: vm.averageScore)

                        // Ruh Hali Dağılımı Kartı
                        if !vm.moodStats.isEmpty {
                            MoodDistributionCard(moodStats: vm.moodStats)
                        }
                        
                        // Puan Zaman Çizelgesi Kartı
                        if !vm.scoreStats.isEmpty {
                            ScoreTimelineCard(scoreStats: vm.scoreStats)
                        }
                        
                        // Boş Durum
                        if vm.moodStats.isEmpty && vm.scoreStats.isEmpty {
                           EmptyState()
                        }
                    }
                    .padding()
                }
                .background(Color.clear)
                .navigationTitle("İstatistikler")
                .toolbar {
                    Button("Yenile") {
                        vm.loadStats()
                    }
                }
            }
        }
    }
}

// MARK: - Alt Bileşenler (Kartlar)

private struct OverviewCard: View {
    let totalAnswered: Int
    let averageScore: Double
    
    var body: some View {
        Card {
            HStack(spacing: 16) {
                VStack {
                    Text("Toplam Kayıt")
                        .font(.caption)
                        .foregroundStyle(Theme.textSec)
                    Text("\(totalAnswered)")
                        .font(.title.bold())
                        .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                VStack {
                    Text("Ort. Puan (Son 30 gün)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSec)
                    Text(String(format: "%.1f", averageScore))
                        .font(.title.bold())
                        .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}


private struct MoodDistributionCard: View {
    let moodStats: [MoodStat]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Ruh Hali Dağılımı", systemImage: "chart.pie.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.textSec)
                
                Chart(moodStats) { stat in
                    BarMark(
                        x: .value("Sayı", stat.count),
                        y: .value("Mod", "\(stat.emoji) \(stat.title)")
                    )
                    .foregroundStyle(by: .value("Mod", stat.title))
                    .annotation(position: .trailing) {
                        Text("\(stat.count)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSec)
                    }
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: CGFloat(moodStats.count) * 40)
            }
        }
    }
}

private struct ScoreTimelineCard: View {
    let scoreStats: [ScoreStat]
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Puan Zaman Çizelgesi (Son 30 Gün)", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(Theme.textSec)

                Chart(scoreStats) { stat in
                    LineMark(
                        x: .value("Tarih", stat.day, unit: .day),
                        y: .value("Puan", stat.score)
                    )
                    .interpolationMethod(.catmullRom) // Çizgiyi yumuşatır
                    
                    AreaMark(
                        x: .value("Tarih", stat.day, unit: .day),
                        y: .value("Puan", stat.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                }
                .chartYScale(domain: 0...10) // Y eksenini 0-10 arası sabitler
                .frame(height: 200)
            }
        }
    }
}


private struct EmptyState: View {
    var body: some View {
        Card {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                Text("Henüz Yeterli Veri Yok")
                    .font(.headline)
                Text("Uygulamayı kullanmaya devam ettikçe, ruh halin ve puanlarınla ilgili ilginç istatistikler burada görünecek.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSec)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}