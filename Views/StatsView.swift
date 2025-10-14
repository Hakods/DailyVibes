//
//  StatsView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 14.10.2025.
//


import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var vm = StatsVM()
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        OverviewCard(totalAnswered: vm.totalAnswered, averageScore: vm.averageScore)
                        
                        // YENİ: Haftanın Ritmi Kartı
                        if !vm.dayOfWeekStats.isEmpty {
                            DayOfWeekChartCard(stats: vm.dayOfWeekStats)
                        }
                        
                        // YENİ: En İyi Anlar Kartı
                        if !vm.highlightEntries.isEmpty {
                            HighlightsCard(entries: vm.highlightEntries)
                        }
                        
                        if !vm.moodStats.isEmpty {
                            MoodDistributionCard(moodStats: vm.moodStats)
                        }
                        
                        if !vm.scoreStats.isEmpty {
                            ScoreTimelineCard(scoreStats: vm.scoreStats)
                        }
                        
                        if vm.moodStats.isEmpty && vm.scoreStats.isEmpty {
                            EmptyState()
                        }
                    }
                    .padding()
                }
                .background(Color.clear)
                .navigationTitle("İstatistikler")
                .toolbar { Button("Yenile") { vm.loadStats() } }
            }
        }
    }
}

// MARK: - Alt Bileşenler

// --- YENİ KART: Haftanın Ritmi ---
private struct DayOfWeekChartCard: View {
    let stats: [DayOfWeekStat]
    
    var body: some View {
        Card {
            VStack(alignment: .leading) {
                Label("Haftanın Ritmi", systemImage: "calendar.day.timeline.leading")
                    .font(.headline)
                    .foregroundStyle(Theme.textSec)
                
                Text("Haftanın günlerine göre ortalama puanların")
                    .font(.caption)
                    .foregroundStyle(Theme.textSec)
                    .padding(.bottom, 8)
                
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Gün", stat.dayName),
                        y: .value("Ortalama Puan", stat.averageScore)
                    )
                    .foregroundStyle(Theme.accentGradient)
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...10)
                .frame(height: 150)
            }
        }
    }
}

// --- YENİ KART: En İyi Anlar ---
private struct HighlightsCard: View {
    let entries: [DayEntry]
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("En İyi Anlar", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Theme.textSec)
                
                ForEach(entries) { entry in
                    NavigationLink(destination: HistoryDetailView(entry: entry)) {
                        HStack {
                            Text(entry.emojiVariant ?? "✨")
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(entry.emojiTitle ?? "Harika Bir Gün")
                                    .font(.subheadline.bold())
                                Text(entry.day.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSec)
                            }
                            Spacer()
                            Text("\(entry.score ?? 10)/10")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.good)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                    if entry.id != entries.last?.id {
                        Divider()
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

// --- GÜNCELLEME BURADA ---
private struct ScoreTimelineCard: View {
    let scoreStats: [ScoreStat]
    
    // YENİ: Türkçe tarih formatını burada tanımlıyoruz.
    private var turkishDateFormat: Date.FormatStyle {
        return .dateTime
            .month(.abbreviated)
            .day()
            .locale(Locale(identifier: "tr_TR"))
    }
    
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
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Tarih", stat.day, unit: .day),
                        y: .value("Puan", stat.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                }
                .chartYScale(domain: 0...10)
                // GÜNCELLEME: X ekseni formatlaması yeni yönteme göre düzeltildi.
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        // Önceden hazırladığımız Türkçe formatı burada kullanıyoruz.
                        AxisValueLabel(format: turkishDateFormat)
                    }
                }
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
