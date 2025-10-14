//
//  StatsVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 14.10.2025.
//


import Foundation
import Combine


struct DayOfWeekStat: Identifiable {
    var id: String { dayName }
    let dayName: String
    let averageScore: Double
    let dayOrder: Int
}

struct MoodStat: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    var count: Int
}

struct ScoreStat: Identifiable {
    let id = UUID()
    let day: Date
    let score: Int
}

@MainActor
final class StatsVM: ObservableObject {
    @Published var dayOfWeekStats: [DayOfWeekStat] = []
    @Published var highlightEntries: [DayEntry] = []
    @Published var moodStats: [MoodStat] = []
    @Published var scoreStats: [ScoreStat] = []
    @Published var averageScore: Double = 0.0
    @Published var totalAnswered: Int = 0
    
    private let repo: DayEntryRepository
    private var cancellable: AnyCancellable?
    
    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        loadStats()
        
        cancellable = RepositoryProvider.shared.entriesChanged
            .sink { [weak self] in
                print("StatsVM: Veri değişikliği sinyali alındı, yenileniyor...")
                self?.loadStats()
            }
    }
    
    func loadStats() {
        guard let entries = try? repo.load() else { return }
        
        let answeredEntries = entries.filter { $0.status == .answered }
        self.totalAnswered = answeredEntries.count
        
        var moodCounts: [String: MoodStat] = [:]
        for entry in answeredEntries {
            guard let title = entry.emojiTitle, let emoji = entry.emojiVariant else { continue }
            
            if var stat = moodCounts[title] {
                stat.count += 1
                moodCounts[title] = stat
            } else {
                moodCounts[title] = MoodStat(emoji: emoji, title: title, count: 1)
            }
        }
        self.moodStats = moodCounts.values.sorted { $0.count > $1.count }
        
        // 2. Puan Zaman Çizelgesini Hesapla (Son 30 gün)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        self.scoreStats = answeredEntries // 'answeredEntries' kullanılıyor
            .filter { $0.day >= thirtyDaysAgo && $0.score != nil }
            .map { ScoreStat(day: $0.day, score: $0.score!) }
            .sorted { $0.day < $1.day }
        
        // 3. Ortalama Puanı Hesapla
        let scores = self.scoreStats.map { $0.score }
        if !scores.isEmpty {
            self.averageScore = Double(scores.reduce(0, +)) / Double(scores.count)
        } else {
            self.averageScore = 0.0
        }
        
        // 4. Haftanın Günü Analizi (Hata düzeltildi)
        calculateDayOfWeekStats(from: answeredEntries) // 'answeredEntries' kullanılıyor
        
        // 5. En İyi Anlar (Hata düzeltildi)
        self.highlightEntries = Array(answeredEntries.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.prefix(3)) // 'answeredEntries' kullanılıyor
    }
    
    private func calculateDayOfWeekStats(from entries: [DayEntry]) {
        let calendar = Calendar.current
        let weekdaySymbols = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"] // Türkçe ve sıralı
        
        let scoresByWeekday = Dictionary(grouping: entries.compactMap { $0.score != nil ? $0 : nil }) { entry -> Int in
            let weekday = calendar.component(.weekday, from: entry.day)
            // Pazar (1) en sona (7) gelsin, diğer günler bir öne gelsin.
            return weekday == 1 ? 7 : weekday - 1
        }
        
        var stats: [DayOfWeekStat] = []
        for i in 1...7 { // 1: Pzt, ..., 7: Paz
            let dayName = weekdaySymbols[i-1]
            
            if let entriesForDay = scoresByWeekday[i] {
                let scores = entriesForDay.compactMap { $0.score }
                if !scores.isEmpty {
                    let average = Double(scores.reduce(0, +)) / Double(scores.count)
                    stats.append(DayOfWeekStat(dayName: dayName, averageScore: average, dayOrder: i))
                }
            } else {
                // Veri olmasa bile grafikte görünmesi için 0 değerli ekleyebiliriz.
                stats.append(DayOfWeekStat(dayName: dayName, averageScore: 0, dayOrder: i))
            }
        }
        
        self.dayOfWeekStats = stats.sorted { $0.dayOrder < $1.dayOrder }
    }
}
