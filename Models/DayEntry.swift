//
//  DayEntry.swift
//  Daily Vibes
//

import Foundation

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
    // --- BU ALANIN DOĞRU EKLENDİĞİNDEN EMİN OLALIM ---
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
        emojiTitle: String? = nil // Bu satırın burada olduğundan emin ol
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
        self.emojiTitle = emojiTitle // Bu satırın burada olduğundan emin ol
    }
    
    // --- KODLAMA VE OKUMA İŞLEMLERİNİ GÜNCELLEYELİM ---
    private enum CodingKeys: String, CodingKey {
        case id, day, scheduledAt, expiresAt, text, status, allowEarlyAnswer, mood, score, emojiVariant, emojiTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.day = try container.decode(Date.self, forKey: .day)
        self.scheduledAt = try container.decode(Date.self, forKey: .scheduledAt)
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.status = try container.decodeIfPresent(EntryStatus.self, forKey: .status) ?? .pending
        self.allowEarlyAnswer = try container.decodeIfPresent(Bool.self, forKey: .allowEarlyAnswer) ?? false
        self.mood = try container.decodeIfPresent(Mood.self, forKey: .mood)
        self.score = try container.decodeIfPresent(Int.self, forKey: .score)
        self.emojiVariant = try container.decodeIfPresent(String.self, forKey: .emojiVariant)
        // Bu satırın eklendiğinden emin ol
        self.emojiTitle = try container.decodeIfPresent(String.self, forKey: .emojiTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(day, forKey: .day)
        try container.encode(scheduledAt, forKey: .scheduledAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encode(status, forKey: .status)
        try container.encode(allowEarlyAnswer, forKey: .allowEarlyAnswer)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(emojiVariant, forKey: .emojiVariant)
        // Bu satırın eklendiğinden emin ol
        try container.encodeIfPresent(emojiTitle, forKey: .emojiTitle)
    }
}


// MARK: - Mood

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy, calm, excited, tired, sick, sad, stressed
    case angry, anxious, bored    // 🔥 yeni çeşitler

    var id: String { rawValue }

    // Varsayılan tek emoji (UI’da varyant seçilirse DayEntry.emojiVariant kullanılır)
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
