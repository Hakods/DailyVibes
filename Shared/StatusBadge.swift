//
//  StatusBadge.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//


import SwiftUI

struct StatusBadge: View {
    let status: EntryStatus
    var body: some View {
        let (txt, col, sys): (String, Color, String) = {
            switch status {
            case .answered: return ("Status.answered", Theme.good, "checkmark.circle.fill")
            case .missed:   return ("Status.missed", Theme.bad,  "exclamationmark.circle.fill")
            case .late:     return ("Status.late", Theme.warn, "clock.badge.exclamationmark.fill")
            case .pending:  return ("Status.pending", Theme.secondary, "hourglass.circle.fill")
            }
        }()
        return Label(txt, systemImage: sys)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(col.opacity(0.14), in: Capsule(style: .continuous))
            .overlay(Capsule().stroke(col.opacity(0.22), lineWidth: 1))
            .foregroundStyle(col)
    }
}
