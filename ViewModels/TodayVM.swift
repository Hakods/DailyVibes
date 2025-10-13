import Foundation
import Combine

@MainActor
final class TodayVM: ObservableObject {
    @Published private(set) var entry: DayEntry?
    @Published var text: String = ""
    @Published var remaining: TimeInterval = 0
    @Published var lastSaveMessage: String? = nil
    
    @Published var selectedMood: Mood? = nil
    @Published var score: Int = 5
    
    // Bu iki alanın burada olduğundan emin ol
    @Published var selectedEmojiVariant: String? = nil
    @Published var selectedEmojiTitle: String? = nil

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
        
        // Mevcut kaydın verilerini yükle
        text = entry?.text ?? ""
        score = entry?.score ?? 5
        selectedMood = entry?.mood
        selectedEmojiVariant = entry?.emojiVariant
        selectedEmojiTitle = entry?.emojiTitle
        
        updateRemaining()
    }
    
    // --- BU FONKSİYONU DİKKATLİCE GÜNCELLE ---
    func saveNow() {
        guard var entryToSave = entry else {
            lastSaveMessage = "Bugün için kayıt bulunamadı."
            return
        }

        let now = Date()
        let withinWindow = (now >= entryToSave.scheduledAt && now <= entryToSave.expiresAt)
        guard entryToSave.allowEarlyAnswer || withinWindow else {
            lastSaveMessage = "Cevap süresi henüz açılmadı."
            return
        }

        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasEmoji = selectedEmojiVariant != nil

        guard hasText || hasEmoji else {
            lastSaveMessage = "Bir emoji seçin veya bir şeyler yazın."
            return
        }

        var list = (try? repo.load()) ?? []
        guard let idx = list.firstIndex(where: { $0.id == entryToSave.id }) else {
            lastSaveMessage = "Kayıt bulunamadı."
            return
        }

        // --- BÜTÜN VERİLERİ BURADA KAYDEDİYORUZ ---
        entryToSave.text = text
        entryToSave.score = score // Puanı kaydet
        entryToSave.mood = selectedMood
        entryToSave.emojiVariant = selectedEmojiVariant // Emojiyi kaydet
        entryToSave.emojiTitle = selectedEmojiTitle     // Emoji başlığını kaydet
        entryToSave.status = .answered
        
        // Listeyi güncelle
        list[idx] = entryToSave
        
        // Diske kaydet
        do {
            try repo.save(list)
            self.entry = entryToSave
            lastSaveMessage = "Kaydedildi ✅"
        } catch {
            lastSaveMessage = "Kaydederken bir hata oluştu."
        }
    }
    
    // Diğer fonksiyonlar
    func updateRemaining() {
        guard let e = entry else { remaining = 0; return }
        remaining = max(0, e.expiresAt.timeIntervalSinceNow)
        if remaining == 0, entry?.status == .pending {
            markMissed()
        }
    }

    func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1, target: self, selector: #selector(handleTick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    @objc private func handleTick() { updateRemaining() }
    
    deinit { timer?.invalidate() }

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
