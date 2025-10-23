import Foundation
import Combine
import UIKit

@MainActor
final class TodayVM: ObservableObject {
    @Published private(set) var entry: DayEntry?
    @Published var text: String = ""
    @Published var remaining: TimeInterval = 0
    @Published var lastSaveMessage: String? = nil
    @Published var selectedMood: Mood? = nil
    @Published var score: Int = 5
    @Published var selectedEmojiVariant: String? = nil
    @Published var selectedEmojiTitle: String? = nil
    @Published var isAnswerWindowActive: Bool = false
    @Published var currentGuidedQuestion: String? = nil
    @Published var guidedAnswer: String = ""
    @Published var showBreathingExercise: Bool = false
    
    private let repo: DayEntryRepository
    private var timer: Timer?
    
    private let guidedQuestions: [Mood?: [String]] = [
        .happy: [
            "Bugün seni en çok ne gülümsetti?",
            "Bu mutluluğu başkalarıyla nasıl paylaştın?",
            "Şu an minnettar olduğun 3 şey nedir?"
        ],
        .calm: [
            "Bu sakinliği nasıl buldun?",
            "Çevrende seni rahatlatan neler var?",
            "Bugün kendine nasıl zaman ayırdın?"
        ],
        .sad: [
            "Bu üzüntüyü tetikleyen ne oldu?",
            "Kendine nasıl şefkat gösterebilirsin?",
            "Şu an neye ihtiyacın olduğunu düşünüyorsun?"
        ],
        .stressed: [
            "Bu stresi en çok nerede hissediyorsun (vücudunda/zihninde)?",
            "Bu durumu hafifletmek için küçük bir adım ne olabilir?",
            "Kontrol edebildiğin ve edemediğin şeyler neler?"
        ],
        .anxious: [
            "Bu kaygıyı düşüncelerinde nasıl fark ediyorsun?",
            "Şu an güvende olduğunu hissetmek için ne yapabilirsin?",
            "Nefesine odaklanmak yardımcı olur mu?"
        ],
        nil: [
            "Bugün beklenmedik bir şey oldu mu?",
            "Bugün öğrendiğin yeni bir şey var mı?",
            "Yarın için küçük bir niyetin ne olabilir?"
        ]
    ]
    
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
        score = entry?.score ?? 5
        selectedEmojiVariant = entry?.emojiVariant
        selectedEmojiTitle = entry?.emojiTitle
        
        currentGuidedQuestion = entry?.guidedQuestion
        guidedAnswer = entry?.guidedAnswer ?? ""
        if entry?.status != .answered || currentGuidedQuestion == nil {
            selectGuidedQuestion()
        }
        
        updateRemaining()
    }
    
    
    private func selectGuidedQuestion() {
        guard entry?.status == .pending, isAnswerWindowActive else {
            currentGuidedQuestion = entry?.guidedQuestion
            return
        }
        
        let currentMood: Mood? = Mood.allCases.first { $0.emoji == selectedEmojiVariant }
        
        let possibleQuestions = guidedQuestions[currentMood] ?? guidedQuestions[nil]!
        currentGuidedQuestion = possibleQuestions.randomElement()
        
        entry?.guidedQuestion = currentGuidedQuestion
    }
    
    func emojiSelectionChanged() {
        selectGuidedQuestion()
    }
    
    func updateRemaining() {
        guard let e = entry else {
            remaining = 0
            isAnswerWindowActive = false
            return
        }
        
        let now = Date()
        remaining = max(0, e.expiresAt.timeIntervalSince(now))
        
        let wasActive = isAnswerWindowActive
        let isActiveNow = (now >= e.scheduledAt && now <= e.expiresAt) || e.allowEarlyAnswer
        
        if isActiveNow != isAnswerWindowActive {
            isAnswerWindowActive = isActiveNow
            if isActiveNow && !wasActive && currentGuidedQuestion == nil {
                selectGuidedQuestion()
            }
        }
        
        if remaining == 0, e.status == .pending {
            markMissed()
        }
    }
    
    func saveNow() {
        guard var entryToSave = entry else {
            lastSaveMessage = "Bugün için kayıt bulunamadı."; return
        }
        
        let now = Date()
        let withinWindow = (now >= entryToSave.scheduledAt && now <= entryToSave.expiresAt)
        guard entryToSave.allowEarlyAnswer || withinWindow else {
            lastSaveMessage = "Cevap süresi henüz açılmadı."; return
        }
        
        var list = (try? repo.load()) ?? []
        guard let idx = list.firstIndex(where: { $0.id == entryToSave.id }) else {
            lastSaveMessage = "Kayıt bulunamadı."; return
        }
        
        entryToSave.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        entryToSave.score = score
        entryToSave.emojiVariant = selectedEmojiVariant
        entryToSave.emojiTitle = selectedEmojiTitle
        entryToSave.status = .answered
      
        entryToSave.guidedQuestion = currentGuidedQuestion
        entryToSave.guidedAnswer = guidedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        list[idx] = entryToSave
        
        do {
            try repo.save(list)
            self.entry = entryToSave
            lastSaveMessage = "Kaydedildi ✅"
            HapticsService.notification(.success)
            RepositoryProvider.shared.entriesChanged.send()
        } catch {
            lastSaveMessage = "Kaydederken bir hata oluştu."
            HapticsService.notification(.error)
        }
    }
    
    func toggleBreathingExercise() {
        showBreathingExercise.toggle()
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
