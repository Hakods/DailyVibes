import Foundation

@MainActor
final class RepositoryProvider {
    // Tekil erişim
    static let shared = RepositoryProvider()

    // Servisler
    let dayRepo: DayEntryRepository
    let notification: NotificationService
    let store: StoreService

    /// App’te kullanılacak varsayılan kurulum
    private init() {
        self.dayRepo      = FileDayEntryRepository()   // somut repo sınıfın buysa kalsın
        self.notification = NotificationService()
        self.store        = StoreService()
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
