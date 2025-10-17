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
    enum Mode { case strict, balanced, creative }
    enum ResponseStyle { case concise, normal, deep }
    
    private let model: GenerativeModel
    
    init() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        self.model = ai.generativeModel(modelName: "gemini-2.5-flash")
        print("✅ AIService, 'gemini-2.5-flash' ile başarıyla başlatıldı.")
    }
    
    func askAIStream(
        question: String,
        entries: [DayEntry],
        mode: Mode,
        style: ResponseStyle,
        useLastDays: Int?,
        useLastCount: Int
    ) -> AsyncThrowingStream<String, Error> {
        
        let scoped = scopeEntries(entries, lastDays: useLastDays, lastCount: useLastCount)
        let prompt = buildPrompt(question: question, entries: scoped, mode: mode, style: style)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try model.generateContentStream(prompt)
                    for try await chunk in stream {
                        if let text = chunk.text, !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func scopeEntries(_ entries: [DayEntry], lastDays: Int?, lastCount: Int) -> [DayEntry] {
        var list = entries
        if let d = lastDays {
            let cutoff = Calendar.current.date(byAdding: .day, value: -d, to: Date()) ?? .distantPast
            list = list.filter { $0.day >= cutoff }
        }
        list.sort { $0.day > $1.day }
        return Array(list.prefix(lastCount))
    }
    
    private func buildPrompt(
        question: String,
        entries: [DayEntry],
        mode: Mode,
        style: ResponseStyle
    ) -> String {
        let entriesText = formatEntriesForAI(entries)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy, EEEE"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        let todayString = dateFormatter.string(from: Date())
        
        let generalGreetings = ["selam", "merhaba", "naber", "nasılsın", "kimsin", "hey"]
        let isGeneralQuestion = generalGreetings.contains { question.lowercased().contains($0) }
        
        let guidance: String
        if isGeneralQuestion {
            guidance = "Kullanıcı genel bir sohbet başlatıyor. Verileri tamamen görmezden gel. Sadece 'Vibe Koçu' rolünle, samimi, kısa ve arkadaşça bir cevap ver."
        } else {
            guidance = "Görevin, genel psikolojik prensiplere dayalı, bilge bir yol arkadaşı gibi konuşmak. 'KULLANICI VERİLERİ'ni sadece bir ilham kaynağı olarak kullan, onlara takılıp kalma."
        }
        
        let brevity = "Cevabın ÇOK KISA ve öz olmalı. Maksimum 4-5 cümle. Asla Markdown (*, # vb.) kullanma."
        
        return """
            Sen 'Vibe Koçu'sun. Davranış kuralların şunlardır:
            - KESİNLİKLE Markdown kullanma (yani *, **, # gibi işaretler kullanma). Cevabın tamamen düz metin (plain text) olsun.
            - Tıbbi tavsiye ASLA verme.
            - \(guidance)
            - \(brevity)
            
            ----
            ÖNEMLİ BİLGİ:
            - Bugünün tarihi: \(todayString)
            - Kullanıcının geçmiş kayıtları aşağıdadır. Sorularını bu tarih bağlamında cevapla ('dün' demek, \(todayString) tarihinden bir önceki gün demektir).
            
            KULLANICI VERİLERİ (Referans için):
            \(entriesText.isEmpty ? "Henüz analiz edilecek kayıt yok." : entriesText)
            ----
            
            KULLANICININ SORUSU: "\(question)"
            """
    }
    
    private func formatEntriesForAI(_ entries: [DayEntry]) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd MMMM yyyy, EEEE"
        df.locale = Locale(identifier: "tr_TR")
        guard !entries.isEmpty else { return "" }
        
        return entries.map { e in
            """
            Tarih: \(df.string(from: e.day))
            Mod: \(e.emojiTitle ?? "Belirtilmemiş") (\(e.emojiVariant ?? ""))
            Puan: \(e.score ?? 0)/10
            Not: \((e.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? e.text! : "Not yok.")
            """
        }.joined(separator: "\n---\n")
    }
}
