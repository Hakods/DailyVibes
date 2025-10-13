//
//  HistoryView.swift
//  Daily Vibes
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var vm = HistoryVM()
    @State private var query: String = ""
    @State private var filter: Filter = .all
    @Namespace private var anim
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        // YENİ: NavigationView eklendi
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                VStack(spacing: 0) {
                    SummaryHeader(entries: vm.entries)
                        .background(Color.clear)
                    
                    VStack(spacing: 12) {
                        Segmented(filter: $filter, anim: anim)
                        SearchBar(text: $query, isFocused: $searchFocused)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    let listData = makeListData()
                    if listData.isEmpty {
                        EmptyState()
                            .padding(.top, 40)
                            .onTapGesture { searchFocused = false }
                    } else {
                        List {
                            ForEach(listData, id: \.monthKey) { section in
                                Section {
                                    ForEach(section.items) { e in
                                        // GÜNCELLEME: NavigationLink'in en doğru kullanımı
                                        NavigationLink {
                                            // Hedef Sayfa
                                            HistoryDetailView(entry: e)
                                        } label: {
                                            // Tıklanacak Görünüm (Kartın kendisi)
                                            HistoryRow(entry: e)
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
                        
                        
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .animation(.easeInOut(duration: 0.18), value: listData.map(\.monthKey))
                        .refreshable { vm.refresh() }
                        .scrollDismissesKeyboard(.interactively)
                        .onTapGesture { searchFocused = false }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { searchFocused = false }
                .padding(.bottom, 4)
                .appBackground()
            }
            .navigationTitle("Geçmiş")
            .toolbar { Button("Yenile") { vm.refresh() } }
        }
    }
    
    // MARK: - Filtreleme & Gruplama
    
    private func makeListData() -> [MonthSection] {
        let today = Calendar.current.startOfDay(for: Date())
        
        // 1) filtrele (sadece bugün ve geçmiş)
        let filtered = vm.entries
            .filter { $0.day <= today }
            .filter {
                switch filter {
                case .all:        return true
                case .answered:   return $0.status == .answered
                case .missed:     return $0.status == .missed
                case .pending:    return $0.status == .pending
                case .todayOnly:  return Calendar.current.isDateInToday($0.day)
                }
            }
            .filter {
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                let inText  = ($0.text ?? "").localizedCaseInsensitiveContains(q)
                let inMood  = $0.mood?.title.localizedCaseInsensitiveContains(q) ?? false
                return inText || inMood
            }
        
        // 2) ay bazlı grupla
        let grouped = Dictionary(grouping: filtered) { (entry: DayEntry) -> MonthKey in
            let comps = Calendar.current.dateComponents([.year, .month], from: entry.day)
            return MonthKey(year: comps.year ?? 0, month: comps.month ?? 0)
        }
        
        // 3) başlıkları hazırla (TR locale)
        let tr = Locale(identifier: "tr_TR")
        let df = DateFormatter()
        df.locale = tr
        df.dateFormat = "LLLL yyyy" // "Ekim 2025"
        
        let sortedKeys = grouped.keys.sorted { (a, b) in (a.year, a.month) > (b.year, b.month) }
        
        return sortedKeys.map { key in
            let comps = DateComponents(calendar: Calendar.current, year: key.year, month: key.month, day: 1)
            let date = comps.date ?? Date()
            let title = df.string(from: date).capitalized(with: tr)
            let items = (grouped[key] ?? []).sorted { $0.day > $1.day }
            return MonthSection(monthKey: key, monthTitle: title, items: items)
        }
    }
    
    // MARK: - Types
    
    enum Filter: Hashable { case all, todayOnly, answered, missed, pending }
    
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
    
    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let answered = entries.filter { $0.status == .answered }.count
        let missed   = entries.filter { $0.status == .missed }.count
        let pendingToday =
        entries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: today) })?.status == .pending
        
        let streak = calcStreak(entries: entries)
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MetricCard(title: "Seri", value: "\(streak) 🔥", subtitle: "art arda gün")
                MetricCard(title: "Cevaplanan", value: "\(answered)", subtitle: "toplam")
                MetricCard(title: "Kaçırılan", value: "\(missed)", subtitle: "toplam")
                if pendingToday {
                    MetricCard(title: "Bugün", value: "Beklemede", subtitle: "henüz yazmadın")
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
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.textSec)
            Text(value).font(.title3.bold())
            Text(subtitle).font(.caption2).foregroundStyle(Theme.textSec)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(.all, "Tümü")
                pill(.todayOnly, "Bugün")
                pill(.answered, "Cevaplanan")
                pill(.missed, "Kaçırılan")
                pill(.pending, "Beklemede")
            }
            .padding(6)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
    
    @ViewBuilder
    private func pill(_ f: HistoryView.Filter, _ title: String) -> some View {
        let isSel = filter == f
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { filter = f }
        } label: {
            Text(title)
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
    
    private var titleTR: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
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
    
    private var moodTitle: String? {
        entry.emojiTitle ?? entry.mood?.title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(titleTR).font(.headline)
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
                    if let emo = moodEmoji, let lbl = moodTitle {
                        HStack(spacing: 6) {
                            Text(emo)
                            Text(lbl)
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
                Text("Metin yok").foregroundStyle(Theme.textSec)
            }
        }
        .padding(.horizontal, 16) // Yatay padding'i buraya taşıdık
        .padding(.vertical, 16)   // Dikey padding zaten vardı
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
    var body: some View {
        VStack(spacing: 12) {
            Text("Henüz geçmiş yok")
                .font(.title3.bold())
            Text("‘Bugün’ bölümünden ilk notunu yazdığında burada göreceksin.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSec)
                .font(.callout)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 24)
    }
}
