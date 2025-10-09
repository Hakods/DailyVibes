//
//  HapticsService.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import UIKit

enum HapticsService {
    static func success() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
