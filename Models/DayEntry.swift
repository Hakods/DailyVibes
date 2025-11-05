//
//  DayEntry.swift
//  Daily Vibes
//

import Foundation
import CoreData

enum EntryStatus: String, Codable {
    case pending, answered, missed, late
}

struct DayEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var day: Date
    var scheduledAt: Date
    var expiresAt: Date
    var text: String? // Ana not alanı
    var status: EntryStatus
    var allowEarlyAnswer: Bool
    
    var mood: Mood?
    var score: Int?
    var emojiVariant: String?
    var emojiTitle: String?
    
    
    init(
        id: UUID = UUID(),
        day: Date,
        scheduledAt: Date,
        expiresAt: Date,
        text: String? = nil,
        status: EntryStatus = .pending,
        allowEarlyAnswer: Bool = false,
        mood: Mood? = nil,
        score: Int? = nil,
        emojiVariant: String? = nil,
        emojiTitle: String? = nil,
    ) {
        self.id = id
        self.day = day
        self.scheduledAt = scheduledAt
        self.expiresAt = expiresAt
        self.text = text
        self.status = status
        self.allowEarlyAnswer = allowEarlyAnswer
        self.mood = mood
        self.score = score
        self.emojiVariant = emojiVariant
        self.emojiTitle = emojiTitle
    }
    
    // --- YENİ: Core Data Entegrasyonu Güncellemesi ---
    // Core Data varlığına da yeni alanları eklememiz gerekecek
    // (Bunu bir sonraki adımda DailyVibes.xcdatamodeld içinde yapacağız)
    init(from coreDataObject: DayEntryCD) {
        self.id = coreDataObject.id ?? UUID()
        self.day = coreDataObject.day ?? Date()
        self.scheduledAt = coreDataObject.scheduledAt ?? Date()
        self.expiresAt = coreDataObject.expiresAt ?? Date()
        self.text = coreDataObject.text
        self.status = EntryStatus(rawValue: coreDataObject.status ?? "pending") ?? .pending
        self.allowEarlyAnswer = coreDataObject.allowEarlyAnswer
        self.score = coreDataObject.score == 0 ? nil : Int(coreDataObject.score)
        self.emojiVariant = coreDataObject.emojiVariant
        self.emojiTitle = coreDataObject.emojiTitle
        self.mood = nil // Mood hala Core Data'da saklanmıyor varsayımıyla
    }
    
    func update(coreDataObject: DayEntryCD) {
        coreDataObject.id = self.id
        coreDataObject.day = self.day
        coreDataObject.scheduledAt = self.scheduledAt
        coreDataObject.expiresAt = self.expiresAt
        coreDataObject.text = self.text
        coreDataObject.status = self.status.rawValue
        coreDataObject.allowEarlyAnswer = self.allowEarlyAnswer
        coreDataObject.score = Int64(self.score ?? 0)
        coreDataObject.emojiVariant = self.emojiVariant
        coreDataObject.emojiTitle = self.emojiTitle
    }
}

// MARK: - Mood

// GÜNCELLEME: Mood enum'una da Codable'ı ekliyoruz.
enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy, calm, excited, tired, sick, sad, stressed
    case angry, anxious, bored
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .happy:    return "😊"
        case .calm:     return "😌"
        case .excited:  return "🤩"
        case .tired:    return "🥱"
        case .sick:     return "🤒"
        case .sad:      return "😔"
        case .stressed: return "😵‍💫"
        case .angry:    return "😠"
        case .anxious:  return "😬"
        case .bored:    return "😐"
        }
    }
    
    var title: String {
        switch self {
        case .happy:    return "Mutlu"
        case .calm:     return "Sakin"
        case .excited:  return "Heyecanlı"
        case .tired:    return "Yorgun"
        case .sick:     return "Hasta"
        case .sad:      return "Üzgün"
        case .stressed: return "Stresli"
        case .angry:    return "Öfkeli"
        case .anxious:  return "Kaygılı"
        case .bored:    return "Sıkılmış"
        }
    }
}

extension Array where Element == DayEntry {
    
    /// DayEntry dizisini, belirtilen dile göre lokalize edilmiş bir CSV String'e dönüştürür.
    func toCSV(locale: Locale, bundle: Bundle) -> String {
        
        // 1. Tarih Formatlayıcıyı Lokalize Et
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = locale // <-- GÜNCELLENDİ
            formatter.timeZone = TimeZone.current
            return formatter
        }()
        
        // 2. Başlık Satırını Lokalize Et
        // (NSLocalizedString kullanarak 'bundle'dan anahtarları çeker)
        let header = [
            NSLocalizedString("csv.header.id", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.day", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.scheduledAt", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.expiresAt", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.status", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.allowEarlyAnswer", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.score", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.emojiVariant", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.emojiTitle", bundle: bundle, comment: "CSV Header"),
            NSLocalizedString("csv.header.note", bundle: bundle, comment: "CSV Header")
        ].joined(separator: ",") + "\n"
        
        // 3. Lokalize Edilmiş Değer Anahtarları
        let yesKey = NSLocalizedString("csv.value.yes", bundle: bundle, comment: "CSV Value")
        let noKey = NSLocalizedString("csv.value.no", bundle: bundle, comment: "CSV Value")
        let noneLabelKey = NSLocalizedString("csv.value.notSpecified", bundle: bundle, comment: "CSV Value")
        let noNoteKey = NSLocalizedString("csv.value.noNote", bundle: bundle, comment: "CSV Value")
        
        // 4. Veri Satırlarını Oluştur
        let dataRows = self.map { entry -> String in
            
            // Emoji Başlığını Lokalize Et (entry.emojiTitle zaten anahtarı tutuyordu)
            let localizedEmojiTitle = NSLocalizedString(entry.emojiTitle ?? noneLabelKey, bundle: bundle, comment: "Emoji title for CSV")
            
            // Durumu Lokalize Et (enum'dan anahtara, oradan çeviriye)
            let localizedStatus = self.localizedStatus(from: entry.status, bundle: bundle)
            
            // Notu Lokalize Et
            let note = (entry.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? entry.text! : noNoteKey
            let safeText = escapeCSVField(note)
            
            // Verileri birleştir
            return [
                entry.id.uuidString,
                dateFormatter.string(from: entry.day),
                dateFormatter.string(from: entry.scheduledAt),
                dateFormatter.string(from: entry.expiresAt),
                localizedStatus,
                entry.allowEarlyAnswer ? yesKey : noKey,
                entry.score.map { String($0) } ?? noneLabelKey,
                entry.emojiVariant ?? "",
                escapeCSVField(localizedEmojiTitle), // Emoji başlıklarında virgül olabilir
                safeText
            ].joined(separator: ",")
        }.joined(separator: "\n")
        
        return header + dataRows
    }
    
    /// (YARDIMCI) EntryStatus enum'ını lokalize edilmiş string'e çevirir.
    private func localizedStatus(from status: EntryStatus, bundle: Bundle) -> String {
        let key: String
        switch status {
        case .answered:
            key = "Status.answered" // "Cevaplandı"
        case .missed:
            key = "Status.missed" // "Kaçırıldı"
        case .late:
            key = "Status.late" // "Geç Cevap"
        case .pending:
            key = "Status.pending" // "Beklemede"
        }
        // Zaten .xcstrings içinde olan anahtarları kullanıyoruz
        return NSLocalizedString(key, bundle: bundle, comment: "Entry status for CSV")
    }
    
    /// CSV alanlarındaki özel karakterlerden kaçınır (bu fonksiyon aynı kaldı).
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        } else {
            return field
        }
    }
}
