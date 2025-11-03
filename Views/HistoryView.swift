//
//  HistoryView.swift
//  Daily Vibes
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var vm = HistoryVM()
    @EnvironmentObject var languageSettings: LanguageSettings
    @State private var query: String = ""
    @State private var filter: Filter = .all
    @Namespace private var anim
    @FocusState private var searchFocused: Bool
    
    private var currentLocale: Locale {
        languageSettings.computedLocale ?? Locale.autoupdatingCurrent
    }
    
    enum Filter: String, CaseIterable {
        case all
        case answered
        case missed
        
        func displayNameKey() -> String {
            switch self {
            case .all: return "history.filter.all"
            case .answered: return "history.filter.answered"
            case .missed: return "history.filter.missed"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                VStack(spacing: 0) {
                    SummaryHeader(entries: vm.entries, locale: currentLocale)
                    
                    VStack(spacing: 12) {
                        Segmented(filter: $filter, anim: anim)
                        SearchBar(text: $query, isFocused: $searchFocused)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    let listData = makeListData(locale: currentLocale)
                    
                    List {
                        if listData.isEmpty {
                            EmptyState(filter: filter, query: query)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.top, 40)
                        } else {
                            ForEach(listData, id: \.monthKey) { section in
                                Section {
                                    ForEach(section.items) { e in
                                        NavigationLink {
                                            HistoryDetailView(entry: e)
                                        } label: {
                                            HistoryRow(entry: e, locale: currentLocale)
                                        }
                                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        .listRowBackground(Color.clear)
                                    }
                                } header: {
                                    MonthHeader(text: section.monthTitle)
                                        .textCase(nil)
                                        .listRowInsets(.init(top: 24, leading: 16, bottom: 8, trailing: 16))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .refreshable { vm.refresh() }
                    .scrollDismissesKeyboard(.interactively)
                }
                .appBackground()
            }
            .navigationTitle(LocalizedStringKey("history.nav.title"))
            .toolbar {
                Button(LocalizedStringKey("button.refresh")) { vm.refresh() }
            }
        }
    }
    
    private func makeListData(locale: Locale) -> [MonthSection] {
        let now = Date()
        
        let filtered = vm.entries
            .filter { entry in
                if entry.status == .pending {
                    return now > entry.expiresAt
                }
                return true
            }
            .filter {
                switch filter {
                case .all: return true
                case .answered: return $0.status == .answered
                case .missed: return $0.status == .missed
                }
            }
            .filter {
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                let inText  = ($0.text ?? "").localizedCaseInsensitiveContains(q)
                let moodKey = ($0.emojiTitle ?? $0.mood?.title ?? "")
                let localizedMoodTitle = NSLocalizedString(moodKey, comment: "Mood title")
                let inMood = localizedMoodTitle.localizedCaseInsensitiveContains(q)
                return inText || inMood
            }
        
        let grouped = Dictionary(grouping: filtered) { (entry: DayEntry) -> MonthKey in
            let comps = Calendar.current.dateComponents([.year, .month], from: entry.day)
            return MonthKey(year: comps.year ?? 0, month: comps.month ?? 0)
        }
        
        let df = DateFormatter()
        df.locale = locale
        df.dateFormat = "LLLL yyyy" // "LLLL" formatı zaten dile duyarlıdır
        
        let sortedKeys = grouped.keys.sorted { (a, b) in (a.year, a.month) > (b.year, b.month) }
        
        return sortedKeys.map { key in
            let comps = DateComponents(calendar: Calendar.current, year: key.year, month: key.month, day: 1)
            let date = comps.date ?? Date()
            // LOKALİZE EDİLDİ: 'capitalized(with: locale)' kullanıldı
            let title = df.string(from: date).capitalized(with: locale)
            let items = (grouped[key] ?? []).sorted { $0.day > $1.day }
            return MonthSection(monthKey: key, monthTitle: title, items: items)
        }
    }
    
    // Types
    struct MonthKey: Hashable { let year: Int; let month: Int }
    struct MonthSection {
        let monthKey: MonthKey
        let monthTitle: String
        let items: [DayEntry]
    }
}

// MARK: - Header: Özet

private struct SummaryHeader: View {
    let entries: [DayEntry]
    let locale: Locale
    
    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let answered = entries.filter { $0.status == .answered }.count
        let missed   = entries.filter { $0.status == .missed }.count
        let pendingToday =
        entries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: today) })?.status == .pending
        
        let streak = calcStreak(entries: entries)
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MetricCard(titleKey: "history.metric.streak", value: "\(streak) 🔥", subtitleKey: "history.metric.streak.sub")
                MetricCard(titleKey: "history.metric.answered", value: "\(answered)", subtitleKey: "history.metric.total")
                MetricCard(titleKey: "history.metric.missed", value: "\(missed)", subtitleKey: "history.metric.total")
                if pendingToday {
                    MetricCard(titleKey: "history.metric.today", value: NSLocalizedString("history.metric.pending", comment:""), subtitleKey: "history.metric.pending.sub")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.clear)
    }
    
    private func calcStreak(entries: [DayEntry]) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        let keyDF = DateFormatter.dayKey
        
        var set: Set<String> = []
        for e in entries where e.status == .answered {
            set.insert(keyDF.string(from: e.day))
        }
        
        var count = 0
        while set.contains(keyDF.string(from: day)) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }
}

private struct MetricCard: View {
    let titleKey: String
    let value: String
    let subtitleKey: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(titleKey)).font(.caption).foregroundStyle(Theme.textSec)
            Text(value).font(.title3.bold())
            Text(LocalizedStringKey(subtitleKey)).font(.caption2).foregroundStyle(Theme.textSec)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Filtre Segmenti

private struct Segmented: View {
    @Binding var filter: HistoryView.Filter
    var anim: Namespace.ID
    
    var body: some View {
        // ScrollView'ı kaldırıp, sona bir Spacer ekleyerek sola yaslıyoruz.
        HStack(spacing: 8) {
            ForEach(HistoryView.Filter.allCases, id: \.self) { f in
                pill(f)
            }
            Spacer() // Bu, tüm butonları sola iter.
        }
        .padding(6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
    
    @ViewBuilder
    private func pill(_ f: HistoryView.Filter) -> some View {
        let isSel = filter == f
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { filter = f }
        } label: {
            Text(LocalizedStringKey(f.displayNameKey()))
                .font(.callout.weight(isSel ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    Group {
                        if isSel {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.accent.opacity(0.12))
                                .matchedGeometryEffect(id: "seg-bg", in: anim)
                        }
                    }
                )
                .foregroundStyle(isSel ? Theme.accent : Theme.textSec)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arama Çubuğu

private struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("Metinde ara…", text: $text)
                .focused(isFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    withAnimation { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .onTapGesture { isFocused.wrappedValue = true }
    }
}

// MARK: - Ay Başlığı

private struct MonthHeader: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 0) // List zaten inset uyguluyor
            .padding(.top, 8)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)  // 👈 şeffaf
    }
}

// MARK: - Satır (Kart)

private struct HistoryRow: View {
    let entry: DayEntry
    let locale: Locale
    
    private var localizedTitle: String {
        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .long
        return df.string(from: entry.day)
    }
    
    private var badgeColor: Color {
        switch entry.status {
        case .answered: return Theme.good
        case .missed:   return Theme.bad
        case .late:     return Theme.warn
        case .pending:  return Theme.accent
        }
    }
    
    private var moodEmoji: String? {
        entry.emojiVariant ?? entry.mood?.emoji
    }
    
    private var moodTitleKey: String? {
        entry.emojiTitle ?? entry.mood?.title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizedTitle).font(.headline)
                Spacer()
                StatusBadge(status: entry.status)
            }
            
            // Saat aralığı
            HStack(spacing: 12) {
                Label(entry.scheduledAt.formatted(date: .omitted, time: .shortened), systemImage: "bell")
                Text("→")
                Text(entry.expiresAt.formatted(date: .omitted, time: .shortened))
                    .foregroundStyle(Theme.textSec)
            }
            .font(.caption)
            
            if moodEmoji != nil || entry.score != nil {
                HStack(spacing: 8) {
                    if let emo = moodEmoji, let lblKey = moodTitleKey {
                        HStack(spacing: 6) {
                            Text(emo)
                            Text(LocalizedStringKey(lblKey))
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    if let s = entry.score {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                            Text("\(s)/10")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            if let t = entry.text, !t.isEmpty {
                Text(t).lineLimit(3)
            } else if moodEmoji == nil && entry.score == nil {
                Text(LocalizedStringKey("Metin yok")).foregroundStyle(Theme.textSec)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(badgeColor.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Boş Durum

private struct EmptyState: View {
    let filter: HistoryView.Filter
    let query: String
    
    var body: some View {
        VStack(spacing: 12) {
            if !query.isEmpty {
                Text(String(format: NSLocalizedString("'%@' için sonuç bulunamadı.", comment: ""), query))
            } else if filter != .all {
                Text(LocalizedStringKey("Bu filtreye uygun kayıt yok."))
            } else {
                Text(LocalizedStringKey("Henüz geçmiş bir kaydın yok."))
            }
        }
        .font(.title3.bold())
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.textSec)
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 24)
    }
}
