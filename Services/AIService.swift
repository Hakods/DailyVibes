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
        mode: Mode = .creative,
        style: ResponseStyle = .concise,
        useLastDays: Int? = 7,
        useLastCount: Int = 3
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

    // --- EN BÜYÜK DEĞİŞİKLİK BURADA: BEYNİ YENİDEN PROGRAMLIYORUZ ---
    private func buildPrompt(
        question: String,
        entries: [DayEntry],
        mode: Mode,
        style: ResponseStyle
    ) -> String {
        let entriesText = formatEntriesForAI(entries)
        
        // GÜNCELLEME 1: Genel sohbeti algılayan bir kontrol
        let generalGreetings = ["selam", "merhaba", "naber", "nasılsın", "kimsin", "hey"]
        let isGeneralQuestion = generalGreetings.contains { question.lowercased().contains($0) }

        let guidance: String
        if isGeneralQuestion {
            // Eğer soru genel bir selamlama ise, analiz modunu tamamen kapat.
            guidance = "Kullanıcı genel bir sohbet başlatıyor. 'KULLANICI VERİLERİ'ni tamamen görmezden gel. Sadece 'Vibe Koçu' rolünle, samimi, kısa ve arkadaşça bir cevap ver. Ona nasıl yardımcı olabileceğini sor."
        } else {
            // Eğer soru analiz gerektiriyorsa, normal modda devam et.
            switch mode {
            case .strict:
                guidance = "Görevin SADECE verilen 'KULLANICI VERİLERİ'ni analiz etmektir. Bu verilerin dışına asla çıkma."
            case .balanced:
                guidance = "Görevin günlük verilerindeki desenleri analiz etmek. Cevabını bu verilere dayandır ama bunları desteklemek için genel tavsiyeler de verebilirsin."
            case .creative:
                guidance = "Görevin, genel psikolojik prensiplere dayalı, bilge bir yol arkadaşı gibi konuşmak. 'KULLANICI VERİLERİ'ni sadece bir ilham kaynağı olarak kullan, onlara takılıp kalma."
            }
        }
        
        let brevity: String
        switch style {
        case .concise:
            brevity = "Cevabın ÇOK KISA ve öz olmalı. Maksimum 4-5 cümle."
        case .normal:
            brevity = "Cevabın orta uzunlukta, birkaç kısa paragraf şeklinde olsun."
        case .deep:
            brevity = "Cevabın ayrıntılı olabilir."
        }

        return """
        Sen 'Vibe Koçu'sun. Davranış kuralların şunlardır:
        - KESİNLİKLE Markdown kullanma (yani *, **, # gibi işaretler kullanma). Cevabın tamamen düz metin (plain text) olsun.
        - Tıbbi tavsiye ASLA verme.
        - Cevapların her zaman pozitif, cesaret verici ve samimi bir dilde olmalı.
        - \(guidance)
        - \(brevity)

        ----
        KULLANICI VERİLERİ (Referans için):
        \(entriesText.isEmpty ? "Kullanıcının henüz analiz edilecek kaydı yok." : entriesText)
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
