//
//  AIService.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 16.10.2025.
//

import Foundation
import FirebaseAI
import FirebaseRemoteConfig

@MainActor
final class AIService {
    enum Mode { case strict, balanced, creative }
    enum ResponseStyle { case concise, normal, deep }
    
    enum AIServiceError: Error {
        case rateLimited
    }
    
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 60
    
    private var model: GenerativeModel
    
    init() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()

        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        
        let defaultModelName = "gemini-2.5-flash"
        remoteConfig.setDefaults([
            "ai_model_name": defaultModelName as NSObject
        ])
        
        let modelName = remoteConfig.configValue(forKey: "ai_model_name").stringValue ?? defaultModelName
        
        print("🤖 AIService Başlatılıyor. Hedef Model: \(modelName)")
        
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        self.model = ai.generativeModel(modelName: modelName)

        remoteConfig.fetchAndActivate { status, error in
            if let error = error {
                print("⚠️ Remote Config hatası: \(error.localizedDescription)")
            } else {
                if status == .successFetchedFromRemote {
                    print("✅ Yeni AI Modeli ismi indirildi! Sonraki başlatmada aktif olacak.")
                }
            }
        }
    }
    // MARK: - Rate Limit Yardımcıları
    
    private func canSendRequest() -> Bool {
        let now = Date()
        requestTimestamps = requestTimestamps.filter { now.timeIntervalSince($0) < 60 }
        return requestTimestamps.count < maxRequestsPerMinute
    }
    
    private func trackRequest() {
        requestTimestamps.append(Date())
    }
        
    func askAIStream(
        chatHistory: [ChatMessage],
        entries: [DayEntry],
        mode: Mode,
        style: ResponseStyle,
        languageCode: String,
        useLastDays: Int?,
        useLastCount: Int
    ) -> AsyncThrowingStream<String, Error> {
        
        let content = PromptContent(languageCode: languageCode)
        let scoped = scopeEntries(entries, lastDays: useLastDays, lastCount: useLastCount)
        
        let prompt = buildPrompt(
            chatHistory: chatHistory,
            entries: scoped,
            mode: mode,
            style: style,
            content: content
        )
        
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                
                // RATE LIMIT KONTROLÜ
                guard self.canSendRequest() else {
                    continuation.finish(throwing: AIServiceError.rateLimited)
                    return
                }
                self.trackRequest()
                
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
    
    // scopeEntries fonksiyonu aynı kalabilir (içinde dil yok)
    private func scopeEntries(_ entries: [DayEntry], lastDays: Int?, lastCount: Int) -> [DayEntry] {
        let now = Date()
        var list = entries.filter { Calendar.current.compare($0.day, to: now, toGranularity: .day) != .orderedDescending }
        list.sort { $0.day > $1.day }
        let result = Array(list.prefix(lastCount))
        return result
    }
    
    private func buildPrompt(
        chatHistory: [ChatMessage],
        entries: [DayEntry],
        mode: Mode,
        style: ResponseStyle,
        content: PromptContent
    ) -> String {
        
        // Veriyi, gelen 'locale' bilgisine göre formatla
        let entriesText = formatEntriesForAI(entries, locale: content.locale)
        
        // Tarihi, gelen 'locale' bilgisine göre formatla
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy, EEEE"
        dateFormatter.locale = content.locale
        let todayString = dateFormatter.string(from: Date())
        
        let lastQuestion = chatHistory.last?.text ?? ""
        
        // Soru analizini dile göre yap
        let lowerQuestion = lastQuestion.lowercased()
        var questionType = "analysis"
        if content.generalGreetings.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "greeting"
        } else if content.specificDataKeywords.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "data"
        } else if content.analysisKeywords.contains(where: { lowerQuestion.contains($0) }) {
            questionType = "analysis"
        } else if content.offTopicKeywords.contains(where: { lowerQuestion.contains($0) })
                    || !entriesText.isEmpty
                    && !lowerQuestion.contains("ben")
                    && !lowerQuestion.contains("his")
                    && !lowerQuestion.contains("günüm")
                    && !lowerQuestion.contains("my")
                    && !lowerQuestion.contains("feel") {
            questionType = "off_topic"
        }
        
        let reminderText = content.reminderVariations.randomElement() ?? content.reminderVariations[0]
        
        let guidance: String
        switch questionType {
        case "data": guidance = content.guidanceData
        case "analysis": guidance = content.guidanceAnalysis
        case "greeting": guidance = content.guidanceGreeting
        case "off_topic": guidance = content.guidanceOffTopic(reminder: reminderText)
        default: guidance = content.guidanceDefault
        }
        
        let brevity: String
        switch style {
        case .concise:
            brevity = content.brevityConcise
        case .normal:
            brevity = content.brevityNormal
        case .deep:
            if questionType == "analysis" {
                brevity = content.brevityDeepAnalysis
            } else {
                brevity = content.brevityNormal
            }
        }
        
        let includeUserData = (questionType != "off_topic" && questionType != "greeting")
        let userDataSection = includeUserData ? """
            \(content.userDataHeader):
            \(entriesText.isEmpty ? content.userDataEmpty : entriesText)
            ----
            """ : ""
        
        let historyText = formatChatHistory(chatHistory, locale: content.locale)
        
        return """
            \(content.systemRole)
            - \(content.ruleMarkdown)
            - \(content.ruleMedical)
            - \(guidance)
            - \(brevity)
            
            ----
            \(content.importantInfoHeader):
            - \(content.todayIs) \(todayString)
            - \(includeUserData ? content.userDataInfo : content.userDataInfoOmitted)
            
            \(userDataSection)
            
            \(content.chatHistoryHeader)
            \(historyText)
            """
    }
    
    
    private func formatChatHistory(_ messages: [ChatMessage], locale: Locale) -> String {
        let langID = locale.language.languageCode?.identifier ?? "en"
        let userLabel = (langID == "tr") ? "Kullanıcı" : "User"
        let modelLabel = (langID == "tr") ? "Koç" : "Coach"
      
        return messages.dropFirst()
            .map { message in
                let label = message.isFromUser ? userLabel : modelLabel
                return "\(label): \(message.text)"
            }
            .joined(separator: "\n\n")
    }
    
    // GÜNCELLENDİ: 'locale' parametresi eklendi
    private func formatEntriesForAI(_ entries: [DayEntry], locale: Locale) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd MMMM yyyy, EEEE"
        df.locale = locale // GÜNCELLENDİ
        guard !entries.isEmpty else { return "" }
        
        let sortedEntries = entries.sorted { $0.day > $1.day }
        
        let langID = locale.language.languageCode?.identifier ?? "en"
        
        let dateLabel = (langID == "tr") ? "Tarih" : "Date"
        let moodLabel = (langID == "tr") ? "Mod" : "Mood"
        let scoreLabel = (langID == "tr") ? "Puan" : "Score"
        let noteLabel = (langID == "tr") ? "Not" : "Note"
        let noneLabel = (langID == "tr") ? "Belirtilmemiş" : "Not specified"
        let noNoteLabel = (langID == "tr") ? "Not yok." : "No note."
        
        return sortedEntries.map { e in
            """
            \(dateLabel): \(df.string(from: e.day))
            \(moodLabel): \(e.emojiTitle ?? noneLabel) (\(e.emojiVariant ?? ""))
            \(scoreLabel): \(e.score.map { "\($0)/10" } ?? noneLabel)
            \(noteLabel): \((e.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? e.text! : noNoteLabel)
            """
        }.joined(separator: "\n---\n")
    }
    
    enum SummaryPeriod: String {
        case week
        case month
    }
    
    func generateSummaryStream(
        entries: [DayEntry],
        period: SummaryPeriod,
        languageCode: String
    ) -> AsyncThrowingStream<String, Error> {
        
        let content = PromptContent(languageCode: languageCode)
        
        // GÜNCELLENDİ: 'content' objesini prompt'a gönder
        let prompt = buildSummaryPrompt(entries: entries, period: period, content: content)
        
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                
                guard self.canSendRequest() else {
                    continuation.finish(throwing: AIServiceError.rateLimited)
                    return
                }
                self.trackRequest()
                
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
    
    // 'content' objesini parametre olarak alır
    private func buildSummaryPrompt(
        entries: [DayEntry],
        period: SummaryPeriod,
        content: PromptContent
    ) -> String {
        
        // GÜNCELLENDİ: Veriyi ve tarihi 'locale'e göre formatla
        let entriesText = formatEntriesForAI(entries, locale: content.locale)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        dateFormatter.locale = content.locale
        
        var dateRangeString = ""
        if let start = entries.first?.day, let end = entries.last?.day {
            dateRangeString = "\(content.summaryDateRangePrefix) \(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
        }
        
        let periodName = (period == .week) ? content.periodWeek : content.periodMonth
        
        // GÜNCELLENDİ: Ana özet prompt'u artık 'content' objesinden geliyor
        return """
            \(content.summaryPromptRole(period: periodName))
            \(content.summaryPromptRules)
            - \(content.summaryPromptAnalyze(dateRange: dateRangeString, period: periodName))
            - \(content.summaryPromptTone)
            - \(content.summaryPromptContent)
            - \(content.summaryPromptLength)
            
            ----
            \(content.userDataHeader) (\(periodName.capitalized) \(content.summaryFor)):
            \(entriesText.isEmpty ? content.summaryDataEmpty : entriesText)
            ----
            
            \(content.summaryGenerateNow(period: periodName)):
            """
    }
}


// YENİ: TÜM DİL METİNLERİNİ YÖNETEN YARDIMCI STRUCT
private struct PromptContent {
    let languageCode: String
    let locale: Locale
    
    // --- Genel ---
    let systemRole: String
    let ruleMarkdown: String
    let ruleMedical: String
    let importantInfoHeader: String
    let todayIs: String
    let userDataInfo: String
    let userDataInfoOmitted: String
    let userDataHeader: String
    let userDataEmpty: String
    let chatHistoryHeader: String
    
    // --- Soru Tipleri (Keywords) ---
    let specificDataKeywords: [String]
    let analysisKeywords: [String]
    let offTopicKeywords: [String]
    let generalGreetings: [String]
    
    // --- Hatırlatmalar (Off-topic) ---
    let reminderVariations: [String]
    
    // --- Rehberlik (Guidance) ---
    let guidanceData: String
    let guidanceAnalysis: String
    let guidanceGreeting: String
    func guidanceOffTopic(reminder: String) -> String {
        let template = (languageCode == "tr") ?
        "Kullanıcının sorusu kişisel duygu durumu veya geçmiş kayıtlarıyla ilgili görünmüyor...\n**Önce, sorduğu genel bilgi sorusunu kendi bilgine dayanarak DOĞRU bir şekilde cevapla.**\n**Ardından, cevabının SONUNA şu cümleyi EKLE:** '%@'"
        :
        "The user's question does not seem related to personal mood or past entries...\n**First, answer the general knowledge question accurately based on your own knowledge.**\n**Then, ADD this sentence to the END of your answer:** '%@'"
        return String(format: template, reminder)
    }
    let guidanceDefault: String
    
    // --- Kısalık (Brevity) ---
    let brevityConcise: String
    let brevityNormal: String
    let brevityDeepAnalysis: String
    
    // --- Özet ---
    let periodWeek: String
    let periodMonth: String
    let summaryFor: String
    let summaryDataEmpty: String
    let summaryDateRangePrefix: String
    func summaryPromptRole(period: String) -> String {
        return (languageCode == "tr") ? "Sen 'Vibe Koçu'sun ve kullanıcının \(period) duygu durumu özetini hazırlıyorsun." : "You are 'Vibe Coach', preparing the user's \(period) mood summary."
    }
    let summaryPromptRules: String
    func summaryPromptAnalyze(dateRange: String, period: String) -> String {
        return (languageCode == "tr") ? "Sana verilen 'KULLANICI VERİLERİ'ni analiz et. Bu veriler \(dateRange) \(period) dönemi temsil ediyor." : "Analyze the 'USER DATA' provided. This data represents the \(period) period \(dateRange)."
    }
    let summaryPromptTone: String
    let summaryPromptContent: String
    let summaryPromptLength: String
    func summaryGenerateNow(period: String) -> String {
        return (languageCode == "tr") ? "Şimdi, bu verilere dayanarak \(period) özeti oluştur:" : "Now, generate the \(period) summary based on this data:"
    }
    
    
    init(languageCode: String) {
        self.languageCode = (languageCode == "tr") ? "tr" : "en"
        
        if self.languageCode == "tr" {
            locale = Locale(identifier: "tr_TR")
            systemRole = "Sen 'Vibe Koçu'sun. Davranış kuralların şunlardır:"
            ruleMarkdown = "KESİNLİKLE Markdown kullanma (*, **, # vb.). Cevabın tamamen düz metin olsun."
            ruleMedical = "Tıbbi veya kesin teşhis niteliğinde tavsiye ASLA verme. 'Bir uzmana danışmak faydalı olabilir' gibi yönlendirmeler yapabilirsin."
            importantInfoHeader = "ÖNEMLİ BİLGİ:"
            todayIs = "Bugünün tarihi:"
            userDataInfo = "Kullanıcının geçmiş kayıtları aşağıdadır ('KULLANICI VERİLERİ')..."
            userDataInfoOmitted = "Bu soru için kullanıcı verileri kullanılmamaktadır."
            userDataHeader = "KULLANICI VERİLERİ (Referans için)"
            userDataEmpty = "Henüz analiz edilecek kayıt yok."
            chatHistoryHeader = "KONUŞMA GEÇMİŞİ:"
            
            specificDataKeywords = ["dün", "geçen hafta", "hangi gün", "kaç kere", "listele", "ne zaman", "skoru", "puanı", "modu", "notu", "kaçtı"]
            analysisKeywords = ["neden", "nasıl", "analiz", "tavsiye", "sebep", "hissetmemin", "sence", "yorumla", "psikolog", "içgörü"]
            offTopicKeywords = ["neresi", "kimdir", "nedir", "ne kadar", "hangi", "kaç yılında", "başkenti", "matematik"]
            generalGreetings = ["selam", "merhaba", "naber", "nasılsın", "kimsin", "hey"]
            
            reminderVariations = [
                "Ancak asıl görevimin, senin duygu durumunu ve girdilerini analiz ederek sana destek olmak olduğunu unutma.",
                "Genel soruları da cevaplayabilirim, ama istersen Vibe'ların hakkında daha derinlemesine konuşabiliriz.",
                "Bu ilginç bir konu! Cevapladıktan sonra, nasıl hissettiğine odaklanmak istersen buradayım.",
                "Elbette, bu konuda bilgim var. Yine de hatırlatmak isterim ki önceliğim senin duygusal yolculuğuna eşlik etmek."
            ]
            
            guidanceData = "Kullanıcı geçmiş kayıtlardan spesifik bir bilgi istiyor. Sadece 'KULLANICI VERİLERİ'ne bak. Eğer veri varsa, veriyi doğrudan sun (Örn: '3 kere 'Üzgün' modu kaydetmişsin'). Veri yoksa 'Bu bilgiye kayıtlarda rastlamadım' de. ASLA yorum yapma."
            guidanceAnalysis = "Kullanıcı bir durumu anlamak, tavsiye almak veya bir analiz istiyor ('neden', 'nasıl', 'sence'). 'KULLANICI VERİLERİ'ni kullanarak DÜŞÜNCELİ, EMPATİK ve DESTEKLEYİCİ bir cevap ver. Verileri yorumla, bağlantılar kur."
            guidanceGreeting = "Kullanıcı genel bir sohbet başlatıyor (selamlaşma). Samimi bir şekilde selamla ve 'Sana nasıl yardımcı olabilirim?' veya 'Bugün nasıl hissediyorsun?' gibi bir soruyla konuyu Vibe'lara getirmeye çalış."
            guidanceDefault = "Kullanıcının sorusunu 'KULLANICI VERİLERİ'ni bağlam olarak kullanarak cevapla."
            
            brevityConcise = "Cevabın ÇOK KISA ve öz olmalı. Maksimum 2-3 cümle (eğer hatırlatma ekliyorsan o hariç)."
            brevityNormal = "Cevabın kısa ve anlaşılır olmalı. Genellikle 4-6 cümle yeterlidir (eğer hatırlatma ekliyorsan o hariç)."
            brevityDeepAnalysis = "Cevabın düşünceli ve biraz daha detaylı olabilir (6-8 cümle)."
            
            // Özet (TR)
            periodWeek = "haftalık"
            periodMonth = "aylık"
            summaryFor = "için"
            summaryDataEmpty = "Bu dönem için analiz edilecek kayıt yok."
            summaryDateRangePrefix = "tarihleri arasını kapsayan"
            summaryPromptRules = "Davranış kuralların şunlardır:\n- KESİNLİKLE Markdown kullanma (*, **, # vb.). Cevabın tamamen düz metin olsun.\n- Tıbbi veya kesin teşhis niteliğinde tavsiye ASLA verme."
            summaryPromptTone = "- Özeti, kullanıcıyla doğrudan konuşuyormuş gibi, samimi ve destekleyici bir dille yaz."
            summaryPromptContent = "- Özetin şunları içermeli (veriler yeterliyse):\n 1. Genel duygu durumu: Bu dönemde en sık hangi modlar hakimdi? (Örn: 'Geçen hafta genel olarak enerjin yüksek görünüyordu...')\n 2. Öne çıkan temalar: Notlarda sıkça geçen konular nelerdi? (Örn: 'Notlarında sık sık 'proje' ve 'yorgunluk' kelimeleri geçmiş.')\n 3. Puanlardaki eğilim: Puanların genel olarak nasıl bir seyir izledi? (Örn: 'Hafta sonuna doğru puanlarında bir düşüş gözlemledim.')\n 4. Küçük bir teşvik veya farkındalık önerisi. (Örn: 'Belki önümüzdeki hafta kendine biraz daha dinlenme zamanı ayırabilirsin?')"
            summaryPromptLength = "- Cevabın DÜŞÜNCELİ ve DETAYLI (ama çok uzun olmayan, 8-10 cümle civarı) olmalı. Veri yoksa veya yetersizse bunu belirt."
            
        } else {
            // --- İNGİLİZCE ---
            locale = Locale(identifier: "en_US")
            systemRole = "You are 'Vibe Coach'. Your rules of conduct are:"
            ruleMarkdown = "ABSOLUTELY do not use Markdown (*, **, #, etc.). Your response must be plain text."
            ruleMedical = "NEVER give medical or diagnostic advice. You can use phrases like 'It might be helpful to consult a professional'."
            importantInfoHeader = "IMPORTANT INFO:"
            todayIs = "Today's date is:"
            userDataInfo = "The user's past entries are below ('USER DATA')..."
            userDataInfoOmitted = "User data is not being used for this question."
            userDataHeader = "USER DATA (For Reference)"
            userDataEmpty = "No entries available to analyze yet."
            chatHistoryHeader = "CONVERSATION HISTORY:"
            
            specificDataKeywords = ["yesterday", "last week", "which day", "how many times", "list", "when", "score", "rating", "mood", "note", "what was"]
            analysisKeywords = ["why", "how", "analyze", "advice", "reason", "feeling", "what do you think", "interpret", "psychologist", "insight"]
            offTopicKeywords = ["where is", "who is", "what is", "how much", "which", "in what year", "capital of", "math"]
            generalGreetings = ["hi", "hello", "hey", "how are you", "who are you"]
            
            reminderVariations = [
                "However, remember that my main purpose is to support you by analyzing your moods and entries.",
                "I can answer general questions, but we can talk more deeply about your Vibes if you'd like.",
                "That's an interesting topic! After I answer, I'm here if you want to focus on how you're feeling.",
                "Certainly, I have information on that. I'd just like to remind you that my priority is to accompany you on your emotional journey."
            ]
            
            guidanceData = "The user wants specific data from past entries. Look ONLY at 'USER DATA'. If data exists, present it directly (e.g., 'You've logged 'Sad' 3 times'). If not, say 'I couldn't find that in the records.' DO NOT interpret."
            guidanceAnalysis = "The user wants to understand a situation, get advice, or an analysis ('why', 'how', 'what do you think'). Give a THOUGHTFUL, EMPATHETIC, and SUPPORTIVE answer using 'USER DATA'. Interpret data, make connections."
            guidanceGreeting = "The user is starting a general chat (greeting). Greet them warmly and try to bring the topic back to Vibes, e.g., 'How can I help you?' or 'How are you feeling today?'"
            guidanceDefault = "Answer the user's question using 'USER DATA' as context."
            
            brevityConcise = "Your answer must be VERY SHORT and concise. Maximum 2-3 sentences (excluding any added reminder)."
            brevityNormal = "Your answer should be short and clear. Usually 4-6 sentences are sufficient (excluding any added reminder)."
            brevityDeepAnalysis = "Your answer can be thoughtful and a bit more detailed (6-8 sentences)."
            
            // Özet (EN)
            periodWeek = "weekly"
            periodMonth = "monthly"
            summaryFor = "for"
            summaryDataEmpty = "No entries to analyze for this period."
            summaryDateRangePrefix = "covering the dates"
            summaryPromptRules = "Your rules of conduct are:\n- ABSOLUTELY do not use Markdown (*, **, #, etc.). Your response must be plain text.\n- NEVER give medical or diagnostic advice."
            summaryPromptTone = "- Write the summary in a friendly and supportive tone, as if talking directly to the user."
            summaryPromptContent = "- The summary should include (if data is sufficient):\n 1. General mood: What moods were dominant? (e.g., 'You seemed to have high energy last week...')\n 2. Prominent themes: What topics came up often in your notes? (e.g., 'The words 'project' and 'tired' appeared frequently.')\n 3. Rating trends: How did your ratings look? (e.g., 'I noticed a dip in your ratings toward the weekend.')\n 4. A small encouragement or awareness suggestion. (e.g., 'Maybe you can set aside more time to rest next week?')"
            summaryPromptLength = "- Your response should be THOUGHTFUL and DETAILED (but not too long, around 8-10 sentences). If data is insufficient, state that."
        }
    }
}
