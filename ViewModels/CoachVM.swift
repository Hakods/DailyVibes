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
    @Published var isCreative: Bool = true        // geçmişe daha az bağlı (creative)
    @Published var shortnessLevel: Double = 0.7   // 0.3 = uzun, 0.7 = kısa, 1.0 = çok kısa
    @Published var isTyping: Bool = false         // "yazıyor..." göstergesi
    @Published var typingSpeed: Double = 0.025    // saniye/karakter (0.01 hızlı, 0.05 yavaş)

    private let repo: DayEntryRepository
    private let aiService = AIService()
    private var streamTask: Task<Void, Never>?

    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        chatMessages.append(ChatMessage(
            text: "Merhaba! Ben Vibe Koçu. İstersen geçmişe az bağlı ve kısa önerilerle yardımcı olabilirim. Sorunu yaz ✨",
            isFromUser: false
        ))
    }
    
    func askQuestion() {
        let trimmed = userQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // UI güncellemesi
        let question = trimmed
        chatMessages.append(ChatMessage(text: question, isFromUser: true))
        userQuestion = ""
        isLoading = true
        isTyping = true

        // varsa önceki akışı iptal et
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }

            // Geçmişi sınırlama (daha özgür his)
            let now = Date()
            let recentDays = isCreative ? 7 : 14
            let maxCount   = isCreative ? 1 : 3

            let entries: [DayEntry] = {
                let all = (try? repo.load()) ?? []
                let cutoff = Calendar.current.date(byAdding: .day, value: -recentDays, to: now) ?? .distantPast
                return all.filter { $0.day >= cutoff }
            }()

            // Kısalık ayarı → maxChars & style
            let maxChars = Int(300 + (1.0 - shortnessLevel) * 500) // 0.7 → ~450–500
            let style: AIService.ResponseStyle = shortnessLevel >= 0.6 ? .concise : .normal
            let mode: AIService.Mode = isCreative ? .creative : .balanced

            let responseStream = aiService.askAIStream(
                question: question,
                entries: entries,
                mode: mode,
                style: style,
                useLastDays: recentDays,
                useLastCount: maxCount,
                maxChars: maxChars
            )

            var aiMessageID: UUID?

            do {
                for try await chunk in responseStream {
                    // harf harf yazma (daktilo) efekti
                    for ch in chunk {
                        try Task.checkCancellation()

                        await MainActor.run {
                            if let id = aiMessageID,
                               let idx = chatMessages.firstIndex(where: { $0.id == id }) {
                                chatMessages[idx].text.append(ch)
                            } else {
                                let newMessage = ChatMessage(text: String(ch), isFromUser: false)
                                aiMessageID = newMessage.id
                                chatMessages.append(newMessage)
                            }
                        }

                        // yazma hızı (typingSpeed saniye/karakter)
                        let nanos = UInt64(max(0.0, typingSpeed) * 1_000_000_000)
                        try await Task.sleep(nanoseconds: nanos)
                    }
                }
            } catch {
                await MainActor.run {
                    chatMessages.append(ChatMessage(
                        text: "Üzgünüm, bir sorun oluştu. Lütfen tekrar dener misin?",
                        isFromUser: false
                    ))
                }
            }

            await MainActor.run {
                isLoading = false
                isTyping = false
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
        isLoading = false
        isTyping = false
    }
}
