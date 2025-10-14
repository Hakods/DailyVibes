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
        // DayEntry artık Decodable olduğu için bu satır çalışacak.
        return try JSONDecoder().decode([DayEntry].self, from: data)
    }

    func save(_ entries: [DayEntry]) throws {
        // DayEntry artık Encodable olduğu için bu satır çalışacak.
        let data = try JSONEncoder().encode(entries)
        // .atomic seçeneği bu şekilde doğru yazılıyor.
        try data.write(to: url, options: .atomic)
    }
    
    // Bu fonksiyonu daha önce eklemiştik, burada olduğundan emin ol.
    func deleteStore() {
        try? FileManager.default.removeItem(at: url)
        print("MIGRATION: Eski 'entries.json' dosyası silindi.")
    }
}
