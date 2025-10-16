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
    
    private let repo: DayEntryRepository
    private let aiService = AIService()
    private var cancellable: AnyCancellable?

    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        chatMessages.append(ChatMessage(text: "Merhaba! Ben Vibe Koçu. Son haftaki kayıtlarınla ilgili merak ettiklerini sorabilirsin.", isFromUser: false))
    }
    
    // GÜNCELLEME: Artık akışı (stream) yönetecek şekilde çalışıyor
    func askQuestion() {
        guard !userQuestion.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let question = userQuestion
        chatMessages.append(ChatMessage(text: question, isFromUser: true))
        userQuestion = ""
        isLoading = true
        
        Task {
            let calendar = Calendar.current
            let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date())!
            let recentEntries = (try? repo.load().filter { $0.day >= twoWeeksAgo }) ?? []
            
            let responseStream = aiService.askAIStream(question: question, with: recentEntries)
            
            var aiMessageID: UUID? = nil
            
            do {
                for try await chunk in responseStream {
                    if let id = aiMessageID, let index = chatMessages.firstIndex(where: { $0.id == id }) {
                        // Var olan mesaja yeni gelen parçayı ekle
                        chatMessages[index].text += chunk
                    } else {
                        // İlk parça geldiğinde, yeni bir mesaj oluştur
                        let newMessage = ChatMessage(text: chunk, isFromUser: false)
                        aiMessageID = newMessage.id
                        chatMessages.append(newMessage)
                    }
                }
            } catch {
                chatMessages.append(ChatMessage(text: "Üzgünüm, bir sorunla karşılaştım. Lütfen tekrar dene.", isFromUser: false))
            }
            
            isLoading = false
        }
    }
}
