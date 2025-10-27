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

        print("➡️ scopeEntries GİRDİ: \(list.count) kayıt. İlk tarih: \(list.min(by: { $0.day < $1.day })?.day.formatted() ?? "N/A"), Son tarih: \(list.max(by: { $0.day < $1.day })?.day.formatted() ?? "N/A")")

        list = list.filter { Calendar.current.compare($0.day, to: now, toGranularity: .day) != .orderedDescending }

        print("   Filtre (Gelecek Hariç): \(list.count) kayıt kaldı.")

        list.sort { $0.day > $1.day }

        let result = Array(list.prefix(lastCount))

        print("⬅️ scopeEntries ÇIKTI: \(result.count) kayıt seçildi (\(lastCount) limitiyle). İlk tarih: \(result.last?.day.formatted() ?? "N/A"), Son tarih: \(result.first?.day.formatted() ?? "N/A")")
        
        return result
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
    
    enum SummaryPeriod: String {
        case week = "Haftalık"
        case month = "Aylık"
    }

    // Yeni Özet Akış Fonksiyonu
    func generateSummaryStream(
        entries: [DayEntry],
        period: SummaryPeriod
    ) -> AsyncThrowingStream<String, Error> {

        // Özet için özel olarak hazırlanmış prompt'u çağır
        let prompt = buildSummaryPrompt(entries: entries, period: period)

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

    // Yeni Özet Prompt Fonksiyonu
    private func buildSummaryPrompt(entries: [DayEntry], period: SummaryPeriod) -> String {
        let entriesText = formatEntriesForAI(entries) // Kayıtları AI formatına çevir

        // Tarih aralığını belirle (varsa)
        let startDate = entries.first?.day
        let endDate = entries.last?.day
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "tr_TR")

        var dateRangeString = ""
        if let start = startDate, let end = endDate {
            dateRangeString = "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end)) tarihleri arasını kapsayan"
        }

        let periodName = period == .week ? "haftalık" : "aylık"

        return """
        Sen 'Vibe Koçu'sun ve kullanıcının \(periodName) duygu durumu özetini hazırlıyorsun.
        Davranış kuralların şunlardır:
        - KESİNLİKLE Markdown kullanma (*, **, # vb.). Cevabın tamamen düz metin olsun.
        - Tıbbi veya kesin teşhis niteliğinde tavsiye ASLA verme.
        - Sana verilen 'KULLANICI VERİLERİ'ni analiz et. Bu veriler \(dateRangeString) \(periodName) dönemi temsil ediyor.
        - Özeti, kullanıcıyla doğrudan konuşuyormuş gibi, samimi ve destekleyici bir dille yaz.
        - Özetin şunları içermeli (veriler yeterliyse):
            - Genel duygu durumu: Bu dönemde en sık hangi modlar hakimdi? Genel olarak nasıl hissettin? (Örn: "Geçen hafta genel olarak enerjin yüksek görünüyordu...")
            - Öne çıkan temalar: Notlarda sıkça geçen veya önemli görünen konular nelerdi? (Örn: "Notlarında sık sık 'proje' ve 'yorgunluk' kelimeleri geçmiş.")
            - Puanlardaki eğilim: Puanların genel olarak nasıl bir seyir izledi? Yüksek veya düşük olduğu günler/zamanlar var mıydı? (Örn: "Hafta sonuna doğru puanlarında bir düşüş gözlemledim.")
            - (İsteğe bağlı) Küçük bir teşvik veya farkındalık önerisi: Gelecek döneme yönelik nazik bir öneri veya gözlem. (Örn: "Belki önümüzdeki hafta kendine biraz daha dinlenme zamanı ayırabilirsin?")
        - Cevabın DÜŞÜNCELİ ve DETAYLI (ama çok uzun olmayan, 8-10 cümle civarı) olmalı. Veri yoksa veya yetersizse bunu belirt.

        ----
        KULLANICI VERİLERİ (\(periodName.capitalized) Özet İçin):
        \(entriesText.isEmpty ? "Bu dönem için analiz edilecek kayıt yok." : entriesText)
        ----

        Şimdi, bu verilere dayanarak \(periodName) özeti oluştur:
        """
    }
}
