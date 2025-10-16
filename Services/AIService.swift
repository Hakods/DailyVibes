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
    enum Mode {
        case strict      // günlük odaklı, az özgür
        case balanced    // orta
        case creative    // daha bağımsız / serbest
    }

    private let model: GenerativeModel

    init() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        self.model = ai.generativeModel(modelName: "gemini-2.5-flash")
    }

    // Stream çağrısı: mod ve kaç gün/kaç kayıt isteyeceğini belirleyebilirsin
    func askAIStream(
        question: String,
        entries: [DayEntry],
        mode: Mode = .balanced,
        useLastDays: Int? = nil,
        useLastCount: Int = 5
    ) -> AsyncThrowingStream<String, Error> {

        // Günlükleri mod’a göre azalt/sadeleştir
        let scoped = scopeEntries(entries, lastDays: useLastDays, lastCount: useLastCount)
        let prompt = buildPrompt(question: question, entries: scoped, mode: mode)

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

    // Günlükleri süreye / sayıya göre daralt
    private func scopeEntries(_ entries: [DayEntry], lastDays: Int?, lastCount: Int) -> [DayEntry] {
        var list = entries
        if let d = lastDays {
            let cutoff = Calendar.current.date(byAdding: .day, value: -d, to: Date()) ?? Date.distantPast
            list = list.filter { $0.day >= cutoff }
        }
        // en yeni kayıtlar öncelikli
        list.sort { $0.day > $1.day }
        return Array(list.prefix(lastCount))
    }

    // Promtu mod’a göre farklılaştır
    private func buildPrompt(question: String, entries: [DayEntry], mode: Mode) -> String {
        let entriesText = formatEntriesForAI(entries)

        let guidance: String
        switch mode {
        case .strict:
            guidance = """
            Verilen günlük verilerine %80 ağırlık ver. Varsayım yapma, veri dışına çok çıkma.
            """
        case .balanced:
            guidance = """
            Günlük verilerine %50, bağımsız yorum ve önerilerine %50 ağırlık ver.
            Veri ile çelişme ama yaratıcı çıkarımlara yer ver.
            """
        case .creative:
            guidance = """
            Günlük verilerini sadece hafif bir referans (%30) olarak kullan.
            Gerekirse verilerle sınırlı kalma; özgürce, yaratıcı ve ilham verici öneriler üret.
            Yine de tıbbi tavsiye verme.
            """
        }

        return """
        Sen, kullanıcıların duygusal farkındalığını artıran 'Vibe Koçu'sun.
        \(guidance)

        ----
        KULLANICI VERİLERİ (özet/kısıtlı):
        \(entriesText.isEmpty ? "Kayıt yok veya kısıtlı gösterim." : entriesText)
        ----
        KULLANICININ SORUSU: "\(question)"
        Cevabı başlıklar ve kısa maddelerle, uygulanabilir önerilerle ver.
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
