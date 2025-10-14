//
//  CoreDataDayEntryRepository.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 14.10.2025.
//


import Foundation
import CoreData

final class CoreDataDayEntryRepository: DayEntryRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func load() throws -> [DayEntry] {
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        let results = try context.fetch(request)
        return results.map { DayEntry(from: $0) }
    }

    func save(_ entries: [DayEntry]) throws {
        // Tüm listeyi alıp Core Data ile senkronize et
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        let existingCDs = try context.fetch(request)
        let existingCDsByID = Dictionary(uniqueKeysWithValues: existingCDs.map { ($0.id!, $0) })
        let entryIDs = Set(entries.map { $0.id })

        // Güncelle veya Yeni Oluştur
        for entry in entries {
            let cdEntry = existingCDsByID[entry.id] ?? DayEntryCD(context: context)
            entry.update(coreDataObject: cdEntry)
        }
        
        // Silinmiş Olanları Kaldır
        for cdEntry in existingCDs {
            if !entryIDs.contains(cdEntry.id!) {
                context.delete(cdEntry)
            }
        }
        
        if context.hasChanges {
            try context.save()
        }
    }
}