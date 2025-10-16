//
//  AIService.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 16.10.2025.
//


import Foundation
import FirebaseAI

@MainActor
final class AIService {

    private let model: GenerativeModel

    init() {
        // Senin bulduğun en doğru başlatma yöntemi:
        // Firebase projesine bağlı Google AI backend'ini kullan.
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        
        // Model adını en güncel ve hızlı olanlardan biriyle güncelleyelim.
        // Not: "gemini-2.5-flash" henüz genel kullanıma açık olmayabilir,
        // "gemini-1.5-flash-latest" daha güvenli bir seçimdir.
        self.model = ai.generativeModel(modelName: "gemini-1.5-flash-latest")
        
        print("✅ AIService, FirebaseAI (Google AI Backend) ile başarıyla başlatıldı.")
    }

    // GÜNCELLEME: Cevabı tek parça halinde almak yerine akış (stream) olarak alıyoruz.
    func askAIStream(question: String, with entries: [DayEntry]) -> AsyncThrowingStream<String, Error> {
        let prompt = buildPrompt(question: question, entries: entries)
        
        // ❗️BURADA "try" ekliyoruz
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let contentStream = try model.generateContentStream(prompt)
                    for try await chunk in contentStream {
                        if let text = chunk.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    print("❌ FirebaseAI Stream Hatası Detayı: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }


    // `buildPrompt` fonksiyonunu daha detaylı hale getiriyoruz.
    private func buildPrompt(question: String, entries: [DayEntry]) -> String {
        let entriesText = formatEntriesForAI(entries)
        
        return """
        Sen, kullanıcıların duygusal farkındalığını artırmalarına yardımcı olan, adı 'Vibe Koçu' olan empatik bir yapay zeka koçusun.
        Kesinlikle tıbbi tavsiye verme. Görevin, sadece kullanıcının sağladığı günlük kayıtlarındaki desenleri fark ederek ona içgörüler sunmaktır.
        Cevapların samimi ve anlaşılır olsun.
        ---
        KULLANICI VERİLERİ:
        \(entriesText)
        ---
        KULLANICININ SORUSU: "\(question)"
        """
    }
    
    // Bu yardımcı fonksiyonu da ekliyoruz.
    private func formatEntriesForAI(_ entries: [DayEntry]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy, EEEE"
        dateFormatter.locale = Locale(identifier: "tr_TR")

        if entries.isEmpty { return "Kullanıcının henüz hiç kaydı yok." }

        return entries.map { entry in
            """
            Tarih: \(dateFormatter.string(from: entry.day))
            Mod: \(entry.emojiTitle ?? "Belirtilmemiş") (\(entry.emojiVariant ?? ""))
            Puan: \(entry.score ?? 0)/10
            Not: \(entry.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? entry.text! : "Not yok.")
            """
        }.joined(separator: "\n---\n")
    }
}
