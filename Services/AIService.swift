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
        let now = Date()
        var list = entries
        
        list = list.filter { Calendar.current.compare($0.day, to: now, toGranularity: .day) != .orderedDescending }
        
        if let d = lastDays {
            let cutoff = Calendar.current.date(byAdding: .day, value: -d, to: now) ?? .distantPast
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
        let entriesText = formatEntriesForAI(entries) // Veriyi formatla

        // Tarih bilgisi
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy, EEEE"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        let todayString = dateFormatter.string(from: Date())

        // Soru Analizi (aynı kalır)
        let lowerQuestion = question.lowercased()
        let specificDataKeywords = ["dün", "geçen hafta", "hangi gün", "kaç kere", "listele", "ne zaman", "skoru", "puanı", "modu", "notu", "kaçtı"]
        let analysisKeywords = ["neden", "nasıl", "analiz", "tavsiye", "sebep", "hissetmemin", "sence", "yorumla", "psikolog"]
        let offTopicKeywords = ["neresi", "kimdir", "nedir", "ne kadar", "hangi", "kaç yılında", "başkenti"]
        let generalGreetings = ["selam", "merhaba", "naber", "nasılsın", "kimsin", "hey"]

        var questionType = "analysis"
        if generalGreetings.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "greeting"
        } else if specificDataKeywords.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "data"
        } else if analysisKeywords.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "analysis"
        } else if offTopicKeywords.contains(where: { lowerQuestion.contains($0) }) || !entriesText.isEmpty && !lowerQuestion.contains("ben") && !lowerQuestion.contains("his") && !lowerQuestion.contains("günüm") {
            questionType = "off_topic"
        }

        // --- Farklı Hatırlatma Metinleri ---
        let reminderVariations = [
            "Ancak asıl görevimin, senin duygu durumunu ve girdilerini analiz ederek sana destek olmak olduğunu unutma.",
            "Genel soruları da cevaplayabilirim, ama istersen Vibe'ların hakkında daha derinlemesine konuşabiliriz.",
            "Bu ilginç bir konu! Cevapladıktan sonra, nasıl hissettiğine odaklanmak istersen buradayım.",
            "Elbette, bu konuda bilgim var. Yine de hatırlatmak isterim ki önceliğim senin duygusal yolculuğuna eşlik etmek."
        ]
        // GÜNCELLEME: Stile göre değil, rastgele seçelim.
        // .randomElement() metodu diziden rastgele bir eleman seçer. Dizi boşsa nil döner,
        // bu yüzden ?? ile varsayılan bir değer (ilk cümle) atıyoruz.
        let reminderText = reminderVariations.randomElement() ?? reminderVariations[0]
        // --- Hatırlatma Metinleri Sonu ---

        // --- Dinamik Rehberlik (Hatırlatıcı metni kullanacak şekilde güncellendi) ---
        let guidance: String
        switch questionType {
            // ... (data, analysis, greeting caseleri aynı kalır) ...
        case "data":
            guidance = """
            Kullanıcı geçmiş kayıtlardan spesifik bir bilgi istiyor... (öncekiyle aynı)
            """
        case "analysis":
            guidance = """
            Kullanıcı bir durumu anlamak... (öncekiyle aynı)
            """
        case "greeting":
            guidance = "Kullanıcı genel bir sohbet başlatıyor (selamlaşma)... (öncekiyle aynı)"

        case "off_topic":
            // Seçilen rastgele reminderText kullanılıyor.
            guidance = """
            Kullanıcının sorusu kişisel duygu durumu veya geçmiş kayıtlarıyla ilgili görünmüyor...
            **Önce, sorduğu genel bilgi sorusunu kendi bilgine dayanarak DOĞRU bir şekilde cevapla.**
            **Ardından, cevabının SONUNA şu cümleyi EKLE:** '\(reminderText)'
            Kullanıcı verilerini bu tür sorular için kullanma.
            """
        default:
            guidance = "Kullanıcının sorusunu 'KULLANICI VERİLERİ'ni bağlam olarak kullanarak..." // (öncekiyle aynı)
        }
        // --- Rehberlik Sonu ---

        // Kısalık (aynı kalabilir)
        let brevity: String
        switch style {
        // ... (öncekiyle aynı)
        case .concise: brevity = "Cevabın ÇOK KISA ve öz olmalı. Maksimum 2-3 cümle (eğer hatırlatma ekliyorsan o hariç)."
        case .normal: brevity = "Cevabın kısa ve anlaşılır olmalı. Genellikle 4-6 cümle yeterlidir (eğer hatırlatma ekliyorsan o hariç)."
        case .deep:
            if questionType == "analysis" { brevity = "Cevabın düşünceli ve biraz daha detaylı olabilir (6-8 cümle)." }
            else { brevity = "Cevabın kısa ve anlaşılır olmalı (4-6 cümle)." }
        }


        // Veri Gizleme (aynı kalabilir)
        let includeUserData = (questionType != "off_topic" && questionType != "greeting")
        let userDataSection = includeUserData ? """
            KULLANICI VERİLERİ (Referans için):
            \(entriesText.isEmpty ? "Henüz analiz edilecek kayıt yok." : entriesText)
            ----
            """ : ""

        // Prompt'un geri kalanı (aynı kalabilir)
        return """
            Sen 'Vibe Koçu'sun. Davranış kuralların şunlardır:
            - KESİNLİKLE Markdown kullanma (*, **, # vb.). Cevabın tamamen düz metin olsun.
            - Tıbbi veya kesin teşhis niteliğinde tavsiye ASLA verme. 'Bir uzmana danışmak faydalı olabilir' gibi yönlendirmeler yapabilirsin.
            - \(guidance)
            - \(brevity)

            ----
            ÖNEMLİ BİLGİ:
            - Bugünün tarihi: \(todayString)
            - \(includeUserData ? "Kullanıcının geçmiş kayıtları aşağıdadır ('KULLANICI VERİLERİ')..." : "Bu soru için kullanıcı verileri kullanılmamaktadır.")

            \(userDataSection)

            KULLANICININ SORUSU: "\(question)"
            """
    }
    
    private func formatEntriesForAI(_ entries: [DayEntry]) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd MMMM yyyy, EEEE"
        df.locale = Locale(identifier: "tr_TR")
        guard !entries.isEmpty else { return "" }
        
        let sortedEntries = entries.sorted { $0.day > $1.day } // En yeniden eskiye
        
        return sortedEntries.map { e in
            """
            Tarih: \(df.string(from: e.day))
            Mod: \(e.emojiTitle ?? "Belirtilmemiş") (\(e.emojiVariant ?? ""))
            Puan: \(e.score.map { "\($0)/10" } ?? "Belirtilmemiş")
            Not: \((e.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? e.text! : "Not yok.")
            """
        }.joined(separator: "\n---\n")
    }
}
