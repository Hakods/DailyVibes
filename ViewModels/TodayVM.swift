//
//  TodayVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//


import Foundation
import Combine

@MainActor
final class TodayVM: ObservableObject {
    @Published private(set) var entry: DayEntry?
    @Published var text: String = ""
    @Published var remaining: TimeInterval = 0
    @Published var lastSaveMessage: String? = nil
    
    @Published var selectedMood: Mood? = nil
    @Published var score: Int = 5  // 1...10
    
    private let repo: DayEntryRepository
    private var timer: Timer?
    
    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        loadToday()
        startTimer()
    }
    
    func loadToday() {
        let entries = (try? repo.load()) ?? []
        let day = Calendar.current.startOfDay(for: Date())
        entry = entries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: day) })
        text = entry?.text ?? ""
        selectedMood = entry?.mood
        score = entry?.score ?? 5
        updateRemaining()
    }
    
    func updateRemaining() {
        guard let e = entry else { remaining = 0; return }
        remaining = max(0, e.expiresAt.timeIntervalSinceNow)
        if remaining == 0, entry?.status == .pending {
            markMissed()
        }
    }

    
    // MARK: - Timer
    
    func startTimer() {
        timer?.invalidate()
        // target/selector kullan: Swift 6 'self capture' problemi yok
        let t = Timer(timeInterval: 1, target: self, selector: #selector(handleTick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    @objc private func handleTick() {
        updateRemaining()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Save / State
    
    func saveNow() {
        guard var e = entry else { lastSaveMessage = "Bugün için kayıt bulunamadı."; return }

        // Pencere kontrolü: allowEarlyAnswer varsa pencereyi bekleme
        let withinWindow = TimeWindow.isWithinWindow(now: Date(), scheduledAt: e.scheduledAt)
        guard e.allowEarlyAnswer || withinWindow else {
            lastSaveMessage = "Cevap süresi henüz açılmadı.";  // istersen mesajı değiştirebilirsin
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { lastSaveMessage = "Boş metin kaydedilemez."; return }

        var list = (try? repo.load()) ?? []
        guard let idx = list.firstIndex(where: { $0.id == e.id }) else {
            lastSaveMessage = "Kayıt bulunamadı."; return
        }

        e.text = trimmed
        e.status = .answered
        // İsteğe bağlı: erken cevaplandıysa bayrağı temizleyebilirsin
        e.allowEarlyAnswer = false

        list[idx] = e
        try? repo.save(list)
        entry = e
        lastSaveMessage = "Kaydedildi ✅"
    }
    
    private func markMissed() {
        guard var e = entry else { return }
        var list = (try? repo.load()) ?? []
        guard let idx = list.firstIndex(where: { $0.id == e.id }) else { return }
        e.status = .missed
        list[idx] = e
        try? repo.save(list)
        entry = e
    }
}

