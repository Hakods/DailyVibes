//
//  Card.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 6.10.2025.
//

import SwiftUI

/// Cam efektli, gölgeli ortak kart helper'ı.
/// Kullanım: Card { /* içerik */ }
@ViewBuilder
public func Card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10, content: content)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
}
