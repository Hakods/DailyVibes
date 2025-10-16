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
    }

    /// Stream: kısalık ve geçmiş etkisini kontrol eden sürüm
    func askAIStream(
        question: String,
        entries: [DayEntry],
        mode: Mode = .creative,                // geçmişe daha az bağlılık için default'u creative yaptım
        style: ResponseStyle = .concise,       // kısa cevap için concise
        useLastDays: Int? = 7,                 // sadece son 7 gün
        useLastCount: Int = 2,                 // en fazla 2 kayıt
        maxChars: Int = 600                    // ~ 4-6 paragrafı geçmesin, istersen 400 yap
    ) -> AsyncThrowingStream<String, Error> {

        let scoped = scopeEntries(entries, lastDays: useLastDays, lastCount: useLastCount)
        let prompt = buildPrompt(question: question, entries: scoped, mode: mode, style: style)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try model.generateContentStream(prompt)
                    var total = 0
                    for try await chunk in stream {
                        if let text = chunk.text, !text.isEmpty {
                            let remaining = max(0, maxChars - total)
                            if remaining <= 0 {
                                // Sert kes: limit aşılınca akışı bitiriyoruz
                                continuation.finish()
                                break
                            }
                            // Parçayı kısaltıp ver
                            let piece = String(text.prefix(remaining))
                            total += piece.count
                            continuation.yield(piece)

                            // Limit tam dolduysa kapat
                            if total >= maxChars {
                                continuation.finish()
                                break
                            }
                        }
                    }
                    // normal bitiş (limit erken kapatmadıysa)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // Günlükleri süreye / sayıya göre daralt
    private func scopeEntries(_ entries: [DayEntry], lastDays: Int?, lastCount: Int) -> [DayEntry] {
        var list = entries
        if let d = lastDays {
            let cutoff = Calendar.current.date(byAdding: .day, value: -d, to: Date()) ?? .distantPast
            list = list.filter { $0.day >= cutoff }
        }
        list.sort { $0.day > $1.day }
        return Array(list.prefix(lastCount))
    }

    // Promptu mod + style'a göre kurgula
    private func buildPrompt(
        question: String,
        entries: [DayEntry],
        mode: Mode,
        style: ResponseStyle
    ) -> String {
        let entriesText = formatEntriesForAI(entries)

        // Geçmişe ağırlık
        let guidance: String
        switch mode {
        case .strict:
            guidance = "Verilen günlük verilerine %80 ağırlık ver; veri dışına nadiren çık."
        case .balanced:
            guidance = "Günlük verilerine %50, genel danışmanlık içgörülerine %50 ağırlık ver."
        case .creative:
            guidance = """
            Günlük verilerini yalnızca hafif bir referans (%30) olarak kullan.
            Gerektiğinde genel psikolojik danışmanlık ilkeleri ve iyi pratiklere dayalı, bağımsız içgörüler sun.
            """
        }

        // Kısalık/derinlik stili
        let brevity: String
        switch style {
        case .concise:
            brevity = "Cevabın en fazla 6–8 cümle olsun; başlık + 3 madde öneri ver; gereksiz tekrar yapma."
        case .normal:
            brevity = "Cevabın orta uzunlukta olsun; başlık + 4–6 madde öneri ver."
        case .deep:
            brevity = "Cevabın ayrıntılı olabilir; fakat yine de net başlıklar ve maddelerle yapılandır."
        }

        // Geçmişi gereksiz referanslamayı azalt
        let referencing = """
        Geçmiş günlüklerden **yalnızca doğrudan alakalı** bir örnek gerekiyorsa 1 kez kısaca bahset; her paragrafta tekrar etme.
        Eğer doğrudan alaka yoksa geçmişi anma.
        """

        return """
        Sen 'Vibe Koçu'sun. Tıbbi tavsiye verme.
        \(guidance)
        \(brevity)
        \(referencing)

        ----
        KULLANICI VERİLERİ (kısıtlı/özet):
        \(entriesText.isEmpty ? "Kayıt yok veya kısıtlı gösterim." : entriesText)
        ----
        KULLANICININ SORUSU: "\(question)"

        Cevabı şu formatta ver:
        1) Kısa başlık
        2) 3 maddelik net, uygulanabilir öneri listesi
        3) 1 cümlelik kapanış
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
