import Foundation
import CoreData
import Combine

@MainActor
final class RepositoryProvider {
    // Tekil erişim
    static let shared = RepositoryProvider()
    
    let entriesChanged = PassthroughSubject<Void, Never>()

    // Servisler
    let dayRepo: DayEntryRepository
    let notification: NotificationService
    let store: StoreService

    /// App’te kullanılacak varsayılan kurulum (Artık CoreData kullanıyor)
    private init() {
        // CoreData context'ini alıyoruz.
        let context = PersistenceController.shared.container.viewContext
        
        // Repository olarak artık CoreDataDayEntryRepository'yi kullanıyoruz.
        self.dayRepo      = CoreDataDayEntryRepository(context: context)
        self.notification = NotificationService()
        self.store        = StoreService()
        
        // Uygulama başlarken eski veriyi taşıma işlemini kontrol et.
        migrateFromFileRepositoryIfNeeded()
    }
    
    /// Eski JSON dosyasındaki verileri CoreData'ya bir defaya mahsus taşıyan fonksiyon.
    private func migrateFromFileRepositoryIfNeeded() {
        let migrationKey = "didMigrateFromFileToCoreData"
        
        // Eğer taşıma daha önce yapıldıysa, fonksiyonu terk et.
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        print("MIGRATION: Eski dosya sisteminden CoreData'ya veri taşıma işlemi başlıyor...")
        
        let fileRepo = FileDayEntryRepository()
        
        do {
            let oldEntries = try fileRepo.load()
            // Eğer taşınacak eski kayıt yoksa, işlemi tamamlandı say ve bitir.
            if oldEntries.isEmpty {
                print("MIGRATION: Taşınacak eski kayıt bulunamadı.")
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            }
            
            // Yeni CoreData deposuna eski kayıtları kaydet.
            try dayRepo.save(oldEntries)
            
            // Taşıma işlemini "tamamlandı" olarak işaretle ki bir daha çalışmasın.
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("MIGRATION: \(oldEntries.count) kayıt başarıyla CoreData'ya taşındı.")
            
            
        } catch {
            print("MIGRATION BAŞARISIZ: Veri taşınırken bir hata oluştu: \(error)")
        }
    }

    /// Test/Preview için DI gerekiyorsa bunu kullan
    init(dayRepo: DayEntryRepository,
         notification: NotificationService,
         store: StoreService) {
        self.dayRepo = dayRepo
        self.notification = notification
        self.store = store
    }
}
