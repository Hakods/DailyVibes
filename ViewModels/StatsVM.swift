//
//  StatsVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 14.10.2025.
//


import Foundation
import Combine

// İstatistik verilerini tutacak struct'lar
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
    @Published var moodStats: [MoodStat] = []
    @Published var scoreStats: [ScoreStat] = []
    @Published var averageScore: Double = 0.0
    @Published var totalAnswered: Int = 0

    private let repo: DayEntryRepository

    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        loadStats()
    }

    func loadStats() {
        guard let entries = try? repo.load() else { return }
        
        // Sadece cevaplanmış veya kaçırılmış kayıtları dikkate al
        let relevantEntries = entries.filter { $0.status == .answered || $0.status == .missed }
        self.totalAnswered = relevantEntries.filter { $0.status == .answered }.count

        // 1. Ruh Hali Dağılımını Hesapla
        var moodCounts: [String: MoodStat] = [:]
        for entry in relevantEntries where entry.status == .answered {
            guard let title = entry.emojiTitle, let emoji = entry.emojiVariant else { continue }
            
            if var stat = moodCounts[title] {
                stat.count += 1
                moodCounts[title] = stat
            } else {
                moodCounts[title] = MoodStat(emoji: emoji, title: title, count: 1)
            }
        }
        // En çok tekrarlanana göre sırala
        self.moodStats = moodCounts.values.sorted { $0.count > $1.count }

        // 2. Puan Zaman Çizelgesini Hesapla (Son 30 gün)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        self.scoreStats = relevantEntries
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
    }
}
