//
//  DayEntryRepository.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation

protocol DayEntryRepository {
    func load() throws -> [DayEntry]
    func save(_ entries: [DayEntry]) throws
}
