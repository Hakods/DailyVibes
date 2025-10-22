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
    
    // Daily Vibes/Services/AIService.swift dosyasındaki buildPrompt fonksiyonunu bununla değiştirin:
    
    private func buildPrompt(
        question: String,
        entries: [DayEntry],
        mode: Mode, // Mode kullanılabilir: örn. creative modda daha az veriye bağlı kalmasını söyleyebiliriz
        style: ResponseStyle
    ) -> String {
        let entriesText = formatEntriesForAI(entries) // Veriyi formatla
        
        // Tarih bilgisi (aynı kalabilir)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy, EEEE"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        let todayString = dateFormatter.string(from: Date())
        
        // Soru Analizi (aynı kalabilir)
        let lowerQuestion = question.lowercased()
        let specificDataKeywords = ["dün", "geçen hafta", "hangi gün", "kaç kere", "listele", "ne zaman", "skoru", "puanı", "modu", "notu"] // Spesifik veri kelimeleri genişletildi
        let analysisKeywords = ["neden", "nasıl", "analiz", "tavsiye", "sebep", "hissetmemin", "sence", "yorumla"] // Analiz kelimeleri genişletildi
        let generalGreetings = ["selam", "merhaba", "naber", "nasılsın", "kimsin", "hey"]
        
        var questionType = "analysis" // Varsayılan: Analiz
        if generalGreetings.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "general"
        } else if specificDataKeywords.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "data"
        } else if analysisKeywords.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "analysis"
        }
        
        // --- GÜNCELLENMİŞ Dinamik Rehberlik ---
        let guidance: String
        switch questionType {
        case "data":
            // NET TALİMAT: Veriye bak ve direkt cevap ver.
            guidance = "Kullanıcı geçmiş kayıtlardan spesifik bir bilgi istiyor (örneğin dünkü mod, puan veya not). **Görevin SADECE sana verilen 'KULLANICI VERİLERİ'ne bakarak bu soruya DOĞRUDAN ve KESİN bir cevap vermektir.** Eğer istenen tarih veya bilgi kayıtlarda yoksa, açıkça 'O tarihe ait kayıt bulunmuyor' veya 'Bu bilgi kayıtlarda belirtilmemiş' de. Yorum yapma, tahmin yürütme, sadece veriyi aktar."
        case "analysis":
            // HİBRİT TALİMAT: Veriyi kullan ama genelleştir.
            guidance = "Kullanıcı bir durumu anlamak, nedenini öğrenmek veya tavsiye almak istiyor. 'KULLANICI VERİLERİ'ni önemli bir **bağlam** olarak kullan. Kayıtlardaki eğilimleri, tekrar eden modları veya notlardaki önemli noktaları fark etmeye çalış. Cevabını oluştururken bu gözlemlerini genel psikolojik prensipler ve empatik bir dille birleştir. Bilge bir yol arkadaşı gibi konuş. **Spesifik bir kayda çok fazla odaklanmaktan kaçın, genel tabloyu yorumla.** Kesin teşhis koyma."
        case "general":
            guidance = "Kullanıcı genel bir sohbet başlatıyor. Sağlanan verileri tamamen görmezden gel. Sadece 'Vibe Koçu' rolünle, samimi, kısa ve arkadaşça bir cevap ver."
        default: // Varsayılan analiz
            guidance = "Kullanıcının sorusunu 'KULLANICI VERİLERİ'ni bağlam olarak kullanarak, genel psikolojik prensipler ve empatik bir yaklaşımla, bilge bir yol arkadaşı gibi cevapla."
        }
        // --- Rehberlik Sonu ---
        
        // Kısalık (aynı kalabilir veya ayarlanabilir)
        let brevity: String
        switch style {
        case .concise: brevity = "Cevabın ÇOK KISA ve öz olmalı. Maksimum 2-3 cümle."
        case .normal: brevity = "Cevabın kısa ve anlaşılır olmalı. Genellikle 4-6 cümle yeterlidir."
        case .deep:
            if questionType == "analysis" { brevity = "Cevabın düşünceli ve biraz daha detaylı olabilir (6-8 cümle)." }
            else { brevity = "Cevabın kısa ve anlaşılır olmalı (4-6 cümle)." }
        }
        
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
            - Kullanıcının geçmiş kayıtları aşağıdadır ('KULLANICI VERİLERİ'). Sorularını bu tarih bağlamında cevapla ('dün' demek, \(todayString) tarihinden bir önceki gün demektir). Eğer sorulan tarihle ilgili veri yoksa veya bilgi eksikse bunu belirt.
            
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
