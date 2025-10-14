//
//  ThemeManager.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 14.10.2025.
//


import SwiftUI
import Combine

// Farklı ruh halleri için renk paletleri tanımlıyoruz.
struct MoodColors {
    let primary: Color
    let secondary: Color
    let tertiary: Color

    static let `default` = MoodColors(primary: Color(hex: "#7C3AED"), secondary: Color(hex: "#06B6D4"), tertiary: Color(hex: "#F59E0B"))
    static let happy = MoodColors(primary: Color(hex: "#F59E0B"), secondary: Color(hex: "#FBBF24"), tertiary: Color(hex: "#FEF9C3"))
    static let sad = MoodColors(primary: Color(hex: "#3B82F6"), secondary: Color(hex: "#60A5FA"), tertiary: Color(hex: "#1E3A8A"))
    static let calm = MoodColors(primary: Color(hex: "#10B981"), secondary: Color(hex: "#34D399"), tertiary: Color(hex: "#A7F3D0"))
    static let angry = MoodColors(primary: Color(hex: "#EF4444"), secondary: Color(hex: "#DC2626"), tertiary: Color(hex: "#F87171"))
    static let anxious = MoodColors(primary: Color(hex: "#6366F1"), secondary: Color(hex: "#4338CA"), tertiary: Color(hex: "#A5B4FC"))
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var currentColors = MoodColors.default
    
    func update(for entry: DayEntry?) {
        guard let entry = entry, entry.status == .answered, let emoji = entry.emojiVariant else {
            currentColors = .default
            return
        }
        
        // Basit bir haritalama yapalım (bu daha da geliştirilebilir)
        switch emoji {
        case "😀", "😄", "😁", "😊", "🙂", "😎", "🥳", "🤗", "🤩", "✨":
            currentColors = .happy
        case "😔", "😢", "😭", "🥺", "😞":
            currentColors = .sad
        case "😌", "🧘‍♀️", "🌿", "🫶", "💫":
            currentColors = .calm
        case "😠", "😡", "🤬", "💢":
            currentColors = .angry
        case "😬", "😰", "😨", "🫨", "😟":
            currentColors = .anxious
        default:
            currentColors = .default
        }
    }
}
