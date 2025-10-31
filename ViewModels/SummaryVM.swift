//
//  SummaryVM.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 22.10.2025.
//


import Foundation
import Combine
import SwiftUI

@MainActor
final class SummaryVM: ObservableObject {
    @Published var weeklySummary: String = ""
    @Published var monthlySummary: String = ""
    @Published var isLoadingWeekly: Bool = false
    @Published var isLoadingMonthly: Bool = false
    @Published var errorMessage: String? = nil

    @Published var canGenerateWeeklySummary: Bool = false
    @Published var canGenerateMonthlySummary: Bool = false

    private let repo: DayEntryRepository
    private let aiService = AIService()
    private var streamTask: Task<Void, Never>?
    private var cancellable: AnyCancellable?

    // UserDefaults Anahtarları
    private let weeklySummaryKey = "savedWeeklySummaryText"
    private let monthlySummaryKey = "savedMonthlySummaryText"
    private let weeklyGenerationDateKey = "savedWeeklySummaryDate"
    private let monthlyGenerationDateKey = "savedMonthlySummaryDate"

    init(repo: DayEntryRepository? = nil) {
        self.repo = repo ?? RepositoryProvider.shared.dayRepo
        loadSavedSummaries() // Kayıtlı özetleri yükle
        checkForNewDataAndUpdateButtonStates() // Başlangıçta durumu kontrol et

        // Yeni kayıt sinyalini dinle
        cancellable = RepositoryProvider.shared.entriesChanged
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                print("SummaryVM: Yeni kayıt algılandı, buton durumları kontrol ediliyor...")
                self?.checkForNewDataAndUpdateButtonStates()
            }
    }

    // Özet oluşturma fonksiyonu (kaydetme dahil)
    func generateSummary(for period: SummaryPeriod) {
        guard canGenerate(for: period), !isLoading(for: period) else {
            print("ℹ️ \(period.rawValue) özeti zaten güncel veya oluşturuluyor.")
            return
        }
        setIsLoading(true, for: period)
        setSummary("", for: period) // Geçici olarak temizle
        errorMessage = nil
        streamTask?.cancel()

        streamTask = Task { [weak self] in
             guard let self else { return }
             var finalSummaryText: String? = nil

             do {
                 let allEntries = try self.repo.load()
                 let relevantEntries = filterEntries(allEntries, for: period)

                 guard relevantEntries.count > 2 else {
                     await MainActor.run {
                         self.setSummary("", for: period)
                         self.saveSummary("", date: Date(), for: period)
                         self.setIsLoading(false, for: period)
                         self.checkForNewDataAndUpdateButtonStates()
                     }
                     return
                 }

                 let aiPeriod: AIService.SummaryPeriod
                 switch period {
                 case .week: aiPeriod = .week
                 case .month: aiPeriod = .month
                 }

                 let responseStream = self.aiService.generateSummaryStream(
                     entries: relevantEntries,
                     period: aiPeriod
                 )

                 var summaryText = ""
                 for try await chunk in responseStream {
                     try Task.checkCancellation()
                     summaryText.append(chunk)
                     // Güncellemeyi MainActor.run içine alalım (zaten @MainActor'dayız ama garanti olsun)
                     await MainActor.run {
                        self.setSummary(summaryText, for: period)
                     }
                 }
                 finalSummaryText = summaryText // Başarıyla bitti

             } catch is CancellationError {
                 print("Özet oluşturma iptal edildi.")
                 await MainActor.run { self.loadSavedSummaries() }
             } catch {
                 print("🛑 SummaryVM: Özet oluşturma hatası: \(error)")
                 await MainActor.run {
                     self.errorMessage = NSLocalizedString("summary.error.generationFailed", comment: "Summary generation failed")
                     self.loadSavedSummaries()
                 }
             }

             // İşlem bitince (MainActor üzerinde)
             await MainActor.run {
                 self.setIsLoading(false, for: period)
                 if let summary = finalSummaryText {
                     self.saveSummary(summary, date: Date(), for: period)
                 }
                 self.checkForNewDataAndUpdateButtonStates()
             }
         }
    }

    func cancel() {
        streamTask?.cancel()
        isLoadingWeekly = false
        isLoadingMonthly = false
        loadSavedSummaries()
        checkForNewDataAndUpdateButtonStates()
    }

    // MARK: - UserDefaults ve Durum Kontrolü

    private func loadSavedSummaries() {
        let defaults = UserDefaults.standard
        weeklySummary = defaults.string(forKey: weeklySummaryKey) ?? ""
        monthlySummary = defaults.string(forKey: monthlySummaryKey) ?? ""
    }

    private func saveSummary(_ text: String, date: Date, for period: SummaryPeriod) {
        let defaults = UserDefaults.standard
        switch period {
        case .week:
            defaults.set(text, forKey: weeklySummaryKey)
            defaults.set(date, forKey: weeklyGenerationDateKey)
            weeklySummary = text // UI'ı güncelle
        case .month:
            defaults.set(text, forKey: monthlySummaryKey)
            defaults.set(date, forKey: monthlyGenerationDateKey)
            monthlySummary = text // UI'ı güncelle
        }
    }

    func checkForNewDataAndUpdateButtonStates() {
        Task { // Bu işlemi arka planda yapabiliriz
             let allEntries = (try? repo.load()) ?? []
             let shouldRegenWeekly = shouldRegenerateSummary(for: .week, allEntries: allEntries)
             let shouldRegenMonthly = shouldRegenerateSummary(for: .month, allEntries: allEntries)

             // @Published değişkenleri main thread'de güncelle
             await MainActor.run {
                 self.canGenerateWeeklySummary = shouldRegenWeekly
                 self.canGenerateMonthlySummary = shouldRegenMonthly
             }
         }
    }

    private func shouldRegenerateSummary(for period: SummaryPeriod, allEntries: [DayEntry]) -> Bool {
        let defaults = UserDefaults.standard
        let generationDateKey: String
        let summaryKey: String

        switch period {
        case .week:
            generationDateKey = weeklyGenerationDateKey
            summaryKey = weeklySummaryKey
        case .month:
            generationDateKey = monthlyGenerationDateKey
            summaryKey = monthlySummaryKey
        }

        let lastGenerationDate = defaults.object(forKey: generationDateKey) as? Date
        let savedSummary = defaults.string(forKey: summaryKey)

        guard let lastDate = lastGenerationDate, let summary = savedSummary, !summary.isEmpty else {
            return filterEntries(allEntries, for: period).count > 2 // Veri varsa oluştur
        }
        
        if !isDate(lastDate, stillValidFor: period) {
             return filterEntries(allEntries, for: period).count > 2 // Yeni dönem için veri varsa oluştur
        }

        let relevantEntries = filterEntries(allEntries, for: period)
        let hasNewData = relevantEntries.contains { $0.day > lastDate }
        return hasNewData // Sadece yeni veri varsa oluştur
    }

    private func isDate(_ date: Date, stillValidFor period: SummaryPeriod) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let referencePeriodStartDate: Date?

        switch period {
        case .week:
             let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
             referencePeriodStartDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek))
        case .month:
             let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
             referencePeriodStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))
        }
        guard let start = referencePeriodStartDate else { return false }
        return calendar.compare(date, to: start, toGranularity: .day) != .orderedAscending
    }

    private func canGenerate(for period: SummaryPeriod) -> Bool {
        switch period {
        case .week: return canGenerateWeeklySummary
        case .month: return canGenerateMonthlySummary
        }
    }

    // --- Diğer Helper Fonksiyonlar ---
    private func isLoading(for period: SummaryPeriod) -> Bool {
        switch period {
        case .week: return isLoadingWeekly
        case .month: return isLoadingMonthly
        }
    }
    private func setIsLoading(_ loading: Bool, for period: SummaryPeriod) {
        switch period {
        case .week: isLoadingWeekly = loading
        case .month: isLoadingMonthly = loading
        }
    }
    private func setSummary(_ text: String, for period: SummaryPeriod) {
        switch period {
        case .week: weeklySummary = text
        case .month: monthlySummary = text
        }
    }
    private func filterEntries(_ entries: [DayEntry], for period: SummaryPeriod) -> [DayEntry] {
        let now = Date()
        let calendar = Calendar.current
        let startDate: Date?
        switch period {
        case .week:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek))
        case .month:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))
        }
        guard let start = startDate else { return [] }
        let endDate: Date?
        switch period {
        case .week:
            endDate = calendar.date(byAdding: .day, value: 7, to: start)
        case .month:
            endDate = calendar.date(byAdding: .month, value: 1, to: start)
        }
        guard let end = endDate else { return [] }
        return entries.filter { $0.status == .answered && $0.day >= start && $0.day < end }
                     .sorted { $0.day < $1.day }
    }
}

// SummaryPeriod enum'ı (Aynı kalır)
enum SummaryPeriod: String {
    case week = "Geçen Hafta"
    case month = "Geçen Ay"
}
