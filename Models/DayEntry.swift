//
//  DayEntry.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation

// Models/DayEntry.swift
enum EntryStatus: String, Codable { case pending, answered, missed, late }

struct DayEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var day: Date
    var scheduledAt: Date
    var expiresAt: Date
    var text: String?
    var status: EntryStatus
    var allowEarlyAnswer: Bool = false   // <-- YENİ (varsayılan false)
    var mood: Mood?      // seçilen emoji ruh hali
    var score: Int?    

    init(id: UUID = UUID(),
         day: Date,
         scheduledAt: Date,
         expiresAt: Date,
         text: String? = nil,
         status: EntryStatus = .pending,
         allowEarlyAnswer: Bool = false) {
        self.id = id
        self.day = day
        self.scheduledAt = scheduledAt
        self.expiresAt = expiresAt
        self.text = text
        self.status = status
        self.allowEarlyAnswer = allowEarlyAnswer
    }
}


// MARK: - Mood

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy, calm, excited, tired, sick, sad, stressed

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
        }
    }
}
