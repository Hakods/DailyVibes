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
    @Published var selectedEmojiTitle: String? = nil
    @Published var isAnswerWindowActive: Bool = false
    @Published var showBreathingExercise: Bool = false
    @Published var showMindfulnessCard: Bool = false
    @Published var dynamicPlaceholder: String = "Bugün aklından neler geçiyor? Birkaç cümle yeter…"
    @Published var selectedEmojiVariant: String? = nil {
        didSet {
            updateDynamicContent()
        }
    }
    
    private let repo: DayEntryRepository
    private var timer: Timer?
    private enum EmojiGroup {
        case mutlu, sakin, uzgun, stresliYorgun, ofkeli, kaygili, hasta, eglenceli, notrKararsiz, bilinmeyen
    }
    
    private func getGroup(for emoji: String?) -> EmojiGroup {
        guard let emoji = emoji else { return .bilinmeyen }
        
        if ["😀", "😄", "😁", "😊", "🙂", "😎", "🥳", "🤗"].contains(emoji) { return .mutlu }
        if ["😌", "🧘‍♀️", "🌿", "🫶", "💫"].contains(emoji) { return .sakin }
        if ["😔", "😢", "😭", "🥺", "😞"].contains(emoji) { return .uzgun }
        if ["🥱", "😪", "😵‍💫", "😫", "🤯"].contains(emoji) { return .stresliYorgun }
        if ["😠", "😡", "🤬", "💢"].contains(emoji) { return .ofkeli }
        if ["😬", "😰", "😨", "🫨", "😟"].contains(emoji) { return .kaygili }
        if ["🤒", "🤕", "🤧", "🥴", "😷"].contains(emoji) { return .hasta }
        if ["🤪", "😜", "😋", "🤩", "✨", "🙃", "😏"].contains(emoji) { return .eglenceli }
        if ["😐", "😶", "🤔", "🫤", "😑"].contains(emoji) { return .notrKararsiz }
        
        return .bilinmeyen
    }
    
    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        loadToday()
        startTimer()
    }
    
    private func updateDynamicContent() {
        let group = getGroup(for: selectedEmojiVariant)
        
        switch group {
        case .mutlu:
            dynamicPlaceholder = "Harika! Bu güzel hissi neye borçlusun?.."
        case .sakin:
            dynamicPlaceholder = "Sakinliğini anlatan birkaç kelime? Günün nasıl huzurlu geçti?.."
        case .uzgun:
            dynamicPlaceholder = "Üzgün hissetmek normal. Ne olduğunu paylaşmak ister misin?.."
        case .stresliYorgun:
            dynamicPlaceholder = "Seni yoran veya strese sokan neydi? Detayları yazmak rahatlatabilir..."
        case .ofkeli:
            dynamicPlaceholder = "Öfkenin kaynağı neydi? İçini dökmek ister misin?.."
        case .kaygili:
            dynamicPlaceholder = "Kaygıların hakkında yazmak, onları yönetmene yardımcı olabilir..."
        case .hasta:
            dynamicPlaceholder = "Geçmiş olsun. Nasıl hissettiğini veya dinlenmek için neler yaptığını yazabilirsin..."
        case .eglenceli:
            dynamicPlaceholder = "Enerjin yüksek! Günün eğlenceli anlarını anlatır mısın?.."
        case .notrKararsiz:
            dynamicPlaceholder = "Nötr veya kararsız hissetmek de bir durum. Aklından neler geçiyor?.."
        case .bilinmeyen:
            dynamicPlaceholder = "Bugün aklından neler geçiyor? Birkaç cümle yeter…"
        }
        
        showMindfulnessCard = (group == .stresliYorgun || group == .ofkeli || group == .kaygili)
    }
    
    func loadToday() {
        let entries = (try? repo.load()) ?? []
        let day = Calendar.current.startOfDay(for: Date())
        entry = entries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: day) })
        
        text = entry?.text ?? ""
        score = entry?.score ?? 5
        selectedEmojiVariant = entry?.emojiVariant
        selectedEmojiTitle = entry?.emojiTitle
        updateDynamicContent()
        updateRemaining()
    }
    
    func updateRemaining() {
        guard let e = entry else {
            remaining = 0
            isAnswerWindowActive = false
            return
        }
        
        let now = Date()
        remaining = max(0, e.expiresAt.timeIntervalSince(now))
        
        let isActiveNow = (now >= e.scheduledAt && now <= e.expiresAt) || e.allowEarlyAnswer
        
        if isActiveNow != isAnswerWindowActive {
            isAnswerWindowActive = isActiveNow
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
