//
//  CoachVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 16.10.2025.
//


import Foundation
import Combine

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var text: String
    let isFromUser: Bool
    
    init(id: UUID = UUID(), text: String, isFromUser: Bool) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
    }
}

@MainActor
final class CoachVM: ObservableObject {
    @Published var chatMessages: [ChatMessage] = []
    @Published var userQuestion: String = ""
    @Published var isLoading = false
    
    // Pro Kontrolü
    @Published var showPaywall = false
    @Published private(set) var freeMessagesRemaining: Int
    
    // GÜNCELLEME: Admin modunu açıp kapatabileceğimiz yeni bir ayar
    @Published var isAdminOverrideEnabled: Bool
    
    private let dailyFreeMessageLimit = 3
    private let store: StoreService
    
    // UI kontrolleri
    @Published var isCreative: Bool = true
    @Published var shortnessLevel: Double = 0.7
    @Published var isTyping: Bool = false
    @Published var typingSpeed: Double = 0.025
    
    private let repo: DayEntryRepository
    private let aiService = AIService()
    private var streamTask: Task<Void, Never>?
    
    init(repo: DayEntryRepository? = nil, store: StoreService) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        self.store = store
        self.freeMessagesRemaining = 0
        
#if DEBUG
        self.isAdminOverrideEnabled = true
#else
        self.isAdminOverrideEnabled = false
#endif
        
        self.freeMessagesRemaining = calculateRemainingMessages()
        updateInitialMessage()
    }
    
    func updateInitialMessage() {
        let initialMessage: String
        if store.isProUnlocked {
            initialMessage = "Merhaba! Ben Vibe Koçu. Sınırsız Pro erişiminle sana yardımcı olmaya hazırım."
        } else if isAdminOverrideEnabled {
            initialMessage = "Merhaba! Ben Vibe Koçu. Admin modu aktif, sınırsız erişime sahipsin. 🚀"
        } else {
            self.freeMessagesRemaining = calculateRemainingMessages()
            initialMessage = "Merhaba! Ben Vibe Koçu. Bugün için \(freeMessagesRemaining) ücretsiz mesaj hakkınla başlayabilirsin ✨"
        }
        
        if chatMessages.first?.text != initialMessage {
            if chatMessages.isEmpty {
                chatMessages.append(ChatMessage(text: initialMessage, isFromUser: false))
            } else {
                chatMessages[0] = ChatMessage(id: chatMessages[0].id, text: initialMessage, isFromUser: false)
            }
        }
    }
    
    func askQuestion() {
        let trimmed = userQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !store.isProUnlocked && !isAdminOverrideEnabled {
            if freeMessagesRemaining <= 0 {
                appendPaywallMessage()
                return
            }
            useFreeMessage()
        }
        
        let question = trimmed
        chatMessages.append(ChatMessage(text: question, isFromUser: true))
        userQuestion = ""
        isLoading = true
        isTyping = true
        
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            
            let recentDays = self.isCreative ? 7 : 14
            let maxCount   = 30
            let entries = (try? self.repo.load()) ?? []
            
            let style: AIService.ResponseStyle = self.shortnessLevel > 0.6 ? .concise : .normal
            let mode: AIService.Mode = self.isCreative ? .creative : .balanced
            
            let responseStream = self.aiService.askAIStream(
                question: question,
                entries: entries,
                mode: mode,
                style: style,
                useLastDays: recentDays,
                useLastCount: maxCount 
            )
            
            var aiMessageID: UUID?
            
            do {
                for try await chunk in responseStream {
                    for char in chunk {
                        try Task.checkCancellation()
                        await MainActor.run {
                            if let id = aiMessageID, let idx = self.chatMessages.firstIndex(where: { $0.id == id }) {
                                self.chatMessages[idx].text.append(char)
                            } else {
                                let newMessage = ChatMessage(text: String(char), isFromUser: false)
                                aiMessageID = newMessage.id
                                self.chatMessages.append(newMessage)
                            }
                        }
                        let nanos = UInt64(max(0.0, self.typingSpeed) * 1_000_000_000)
                        try await Task.sleep(nanoseconds: nanos)
                    }
                }
            } catch {
                await MainActor.run {
                    self.chatMessages.append(ChatMessage(text: "Üzgünüm, bir sorun oluştu.", isFromUser: false))
                }
            }
            
            await MainActor.run {
                self.isLoading = false
                self.isTyping = false
            }
        }
    }
    
    // YENİ FONKSİYONLAR
    private func appendPaywallMessage() {
        let paywallMessage = ChatMessage(text: "Günlük ücretsiz mesaj limitine ulaştın. Sınırsız sohbet ve daha derin analizler için Pro'ya geçmeye ne dersin?", isFromUser: false)
        chatMessages.append(paywallMessage)
        // Arayüzün ödeme duvarını göstermesi için sinyal gönder
        showPaywall = true
    }
    
    private func calculateRemainingMessages() -> Int {
        let defaults = UserDefaults.standard
        let lastUsedDate = defaults.object(forKey: "lastAImessageDate") as? Date ?? .distantPast
        
        if !Calendar.current.isDateInToday(lastUsedDate) {
            defaults.set(dailyFreeMessageLimit, forKey: "aiMessageCount")
            defaults.set(Date(), forKey: "lastAImessageDate") // Tarihi bugüne güncelle
            return dailyFreeMessageLimit
        }
        
        return defaults.integer(forKey: "aiMessageCount")
    }
    
    private func useFreeMessage() {
        freeMessagesRemaining -= 1
        UserDefaults.standard.set(freeMessagesRemaining, forKey: "aiMessageCount")
        UserDefaults.standard.set(Date(), forKey: "lastAImessageDate")
    }
    
    func cancel() {
        streamTask?.cancel()
        isLoading = false
        isTyping = false
    }
}
