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
    
    @Published private(set) var isProCached: Bool = false
    @Published private(set) var subscriptionReady: Bool = false
    
    var effectivePro: Bool { isProCached || !subscriptionReady }
    
    // Pro Kontrolü
    @Published var showPaywall = false
    @Published private(set) var freeMessagesRemaining: Int
    
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
    
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var currentLangCode: String = "system"
    private(set) var currentBundle: Bundle = .main
    
    init(repo: DayEntryRepository? = nil, store: StoreService) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        self.store = store
        self.isProCached = store.isProUnlocked
        self.freeMessagesRemaining = 0
        self.freeMessagesRemaining = calculateRemainingMessages()
        store.$isProUnlocked
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPro in
                guard let self else { return }
                self.isProCached = isPro
                self.subscriptionReady = true
                self.updateInitialMessage()
            }
            .store(in: &cancellables)
        
        store.$isReady
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ready in
                self?.subscriptionReady = ready
                self?.updateInitialMessage()
            }
            .store(in: &cancellables)
    }
    
    func updateLanguage(langCode: String) {
        let newCode: String
        if langCode == "system" {
            newCode = Bundle.main.preferredLocalizations.first ?? "en"
        } else {
            newCode = langCode
        }
        
        guard newCode != self.currentLangCode || self.chatMessages.isEmpty else {
            return
        }
        
        print("VIBE COACH DİLİ GÜNCELLENİYOR: \(newCode)")
        self.currentLangCode = newCode
        
        if let path = Bundle.main.path(forResource: newCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.currentBundle = bundle
        } else {
            self.currentBundle = .main
        }
        updateInitialMessage()
    }
    
    
    func updateInitialMessage() {
        let isPro = effectivePro
        let initialMessage: String
        if isPro {
            initialMessage = NSLocalizedString("vibeCoach.welcome.pro", bundle: self.currentBundle, comment: "")
        } else {
            self.freeMessagesRemaining = calculateRemainingMessages()
            let fmt = NSLocalizedString("vibeCoach.welcome.free", bundle: self.currentBundle, comment: "")
            initialMessage = String(format: fmt, freeMessagesRemaining)
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
        
        let isPro = effectivePro
        
        if !isPro {
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
                chatHistory: chatMessages,
                entries: entries,
                mode: mode,
                style: style,
                languageCode: self.currentLangCode,
                useLastDays: recentDays,
                useLastCount: maxCount
            )
            
            var aiMessageID: UUID?
            
            do {
                for try await chunk in responseStream {
                    for char in chunk {
                        try Task.checkCancellation()
                        await MainActor.run {
                            if let id = aiMessageID,
                               let idx = self.chatMessages.firstIndex(where: { $0.id == id }) {
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
                    if let aiError = error as? AIService.AIServiceError,
                       case .rateLimited = aiError {
                        // Rate limit'e özel mesaj
                        let text = NSLocalizedString("vibeCoach.error.rateLimit",
                                                     bundle: self.currentBundle,
                                                     comment: "Rate limit error")
                        self.chatMessages.append(ChatMessage(text: text, isFromUser: false))
                    } else {
                        // Generic hata
                        let text = NSLocalizedString("vibeCoach.error.generic",
                                                     bundle: self.currentBundle,
                                                     comment: "Generic error message in chat")
                        self.chatMessages.append(ChatMessage(text: text, isFromUser: false))
                    }
                }
            }
            
            await MainActor.run {
                self.isLoading = false
                self.isTyping = false
            }
        }
    }
    
    private func appendPaywallMessage() {
        guard subscriptionReady else { return }
        let paywallText = NSLocalizedString("vibeCoach.paywall.upsell", bundle: self.currentBundle, comment: "")
        if chatMessages.last?.text != paywallText {
            chatMessages.append(ChatMessage(text: paywallText, isFromUser: false))
            showPaywall = true
        }
    }
    
    private func calculateRemainingMessages() -> Int {
        let defaults = UserDefaults.standard
        let lastUsedDate = defaults.object(forKey: "lastAImessageDate") as? Date ?? .distantPast
        
        if !Calendar.current.isDateInToday(lastUsedDate) {
            defaults.set(dailyFreeMessageLimit, forKey: "aiMessageCount")
            defaults.set(Date(), forKey: "lastAImessageDate")
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
