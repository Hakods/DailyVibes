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
    var text: String?
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
        emojiTitle: String? = nil
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
}

// Core Data dönüşüm extension'ı aynı kalabilir
extension DayEntry {
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
        self.mood = nil
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
