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
    
    func getEntry(for date: Date) throws -> DayEntry?
    func getEntries(from startDate: Date, to endDate: Date) throws -> [DayEntry]
    func save(entry: DayEntry) throws
    func delete(entry: DayEntry) throws
}
