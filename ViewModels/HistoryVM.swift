//
//  HistoryVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation
import Combine

@MainActor
final class HistoryVM: ObservableObject {
    @Published var entries: [DayEntry] = []

    private let repo: DayEntryRepository

    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        refresh()
    }

    func refresh() {
        Task { @MainActor in
            var list = (try? repo.load()) ?? []
            let now = Date()

            var changed = false
            for i in list.indices {
                if list[i].status == .pending && list[i].expiresAt < now {
                    list[i].status = .missed
                    changed = true
                }
            }

            if changed { try? repo.save(list) }

            // en yeni gün en üstte
            entries = list.sorted { $0.day > $1.day }
        }
    }
}
