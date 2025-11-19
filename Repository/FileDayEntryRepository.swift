//
//  FileDayEntryRepository.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import Foundation

final class FileDayEntryRepository: DayEntryRepository {
    private let filename = "entries.json"
    private var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func load() throws -> [DayEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([DayEntry].self, from: data)
    }

    func save(_ entries: [DayEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: .atomic)
    }
    
    func getEntry(for date: Date) throws -> DayEntry? {
        let allEntries = try load()
        let calendar = Calendar.current
        return allEntries.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func getEntries(from startDate: Date, to endDate: Date) throws -> [DayEntry] {
        let allEntries = try load()
        // Tarih aralığındakileri filtrele
        return allEntries.filter { $0.day >= startDate && $0.day <= endDate }
            .sorted { $0.day < $1.day }
    }

    func save(entry: DayEntry) throws {
        var allEntries = try load()
        
        if let index = allEntries.firstIndex(where: { $0.id == entry.id }) {
            // Varsa güncelle
            allEntries[index] = entry
        } else {
            // Yoksa ekle
            allEntries.append(entry)
        }
        
        try save(allEntries)
    }
    
    func delete(entry: DayEntry) throws {
        var allEntries = try load()
        allEntries.removeAll { $0.id == entry.id }
        try save(allEntries)
    }
    
    // MARK: - Migration Yardımcısı
    func deleteStore() {
        try? FileManager.default.removeItem(at: url)
        print("MIGRATION: Eski 'entries.json' dosyası silindi.")
    }
}
