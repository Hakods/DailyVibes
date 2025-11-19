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

    func getEntry(for date: Date) throws -> DayEntry? {
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        
        request.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        request.fetchLimit = 1

        let results = try context.fetch(request)
        return results.first.map { DayEntry(from: $0) }
    }

    func getEntries(from startDate: Date, to endDate: Date) throws -> [DayEntry] {
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        
        request.predicate = NSPredicate(format: "day >= %@ AND day <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)]

        let results = try context.fetch(request)
        return results.map { DayEntry(from: $0) }
    }

    func save(entry: DayEntry) throws {
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        let cdEntry: DayEntryCD
        
        if let existing = results.first {
            cdEntry = existing
        } else {
            cdEntry = DayEntryCD(context: context)
        }
        
        entry.update(coreDataObject: cdEntry)
        
        saveContext()
    }
    
    // MARK: - Silme İşlemi
    func delete(entry: DayEntry) throws {
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        request.fetchLimit = 1
        
        if let objectToDelete = try context.fetch(request).first {
            context.delete(objectToDelete)
            saveContext()
        }
    }

    // MARK: - ESKİ METODLAR (Geriye uyumluluk & Toplu işlemler için optimize edildi)
    
    func load() throws -> [DayEntry] {
        // Yine de tümünü çekmen gerekiyorsa en azından sıralı çekelim
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        request.sortDescriptors = [NSSortDescriptor(key: "day", ascending: false)]
        
        let results = try context.fetch(request)
        return results.map { DayEntry(from: $0) }
    }

    func save(_ entries: [DayEntry]) throws {
        // Toplu kaydetme ihtiyacı olursa diye (Loop içinde fetch yapmamak için ID listesiyle çekiyoruz)
        guard !entries.isEmpty else { return }
        
        let ids = entries.map { $0.id }
        let request = NSFetchRequest<DayEntryCD>(entityName: "DayEntryCD")
        request.predicate = NSPredicate(format: "id IN %@", ids)
        
        let existingCDs = try context.fetch(request)
        // Dictionary ile hızlı erişim sağla
        let existingMap = Dictionary(uniqueKeysWithValues: existingCDs.map { ($0.id!, $0) })
        
        for entry in entries {
            let cdEntry = existingMap[entry.id] ?? DayEntryCD(context: context)
            entry.update(coreDataObject: cdEntry)
        }
        
        saveContext()
    }
    
    // Yardımcı: Değişiklik varsa commit et
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("CoreData Save Error: \(nsError), \(nsError.userInfo)")
                // Burada bir log mekanizması veya crashlytics olabilir
            }
        }
    }
}
