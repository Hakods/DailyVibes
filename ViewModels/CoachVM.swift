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

    // UI kontrolleri:
    @Published var isCreative: Bool = true
    @Published var shortnessLevel: Double = 0.7
    @Published var isTyping: Bool = false
    @Published var typingSpeed: Double = 0.025

    private let repo: DayEntryRepository
    private let aiService = AIService()
    private var streamTask: Task<Void, Never>?

    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        chatMessages.append(ChatMessage(
            text: "Merhaba! Ben Vibe Koçu. Merak ettiklerini sorabilirsin ✨",
            isFromUser: false
        ))
    }
    
    func askQuestion() {
        let trimmed = userQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let question = trimmed
        chatMessages.append(ChatMessage(text: question, isFromUser: true))
        userQuestion = ""
        isLoading = true
        isTyping = true

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }

            let recentDays = self.isCreative ? 7 : 14
            let maxCount   = self.isCreative ? 3 : 5
            
            let entries: [DayEntry] = {
                let all = (try? self.repo.load()) ?? []
                let cutoff = Calendar.current.date(byAdding: .day, value: -recentDays, to: Date()) ?? .distantPast
                return all.filter { $0.day >= cutoff }
            }()
            
            // GÜNCELLEME: Slider'dan gelen değeri daha basit bir 'style'a çeviriyoruz.
            let style: AIService.ResponseStyle = self.shortnessLevel > 0.6 ? .concise : .normal
            let mode: AIService.Mode = self.isCreative ? .creative : .balanced

            // GÜNCELLEME: `maxChars` argümanını buradan kaldırıyoruz.
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
                    self.chatMessages.append(ChatMessage(
                        text: "Üzgünüm, bir sorun oluştu. Lütfen tekrar dener misin?",
                        isFromUser: false
                    ))
                }
            }

            await MainActor.run {
                self.isLoading = false
                self.isTyping = false
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
        isLoading = false
        isTyping = false
    }
}
