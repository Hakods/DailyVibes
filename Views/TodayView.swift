//
//  TodayView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import SwiftUI

struct TodayView: View {
    @StateObject private var vm = TodayVM()
    @FocusState private var isEditing: Bool
    @State private var showSavedToast = false
    @State private var showAlert = false
    @State private var alertText = ""
    @Namespace private var anim
    private let editorAnchorID = "EDITOR_ANCHOR"
    
    struct Msg: Identifiable { let id: UUID; let text: String }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AnimatedAuroraBackground()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        
                        if let e = vm.entry {
                            Card {
                                // YENİ GÖRÜNÜM: Duruma göre farklı bir üst kısım gösteriyoruz.
                                if e.status == .pending {
                                    PendingStateView() // Saat yerine gizemli bir kart
                                } else {
                                    answeredBlock(for: e) // Cevaplandıysa direkt sonucu göster
                                }
                                
                                // Sadece cevaplama zamanı geldiğinde diğer kontrolleri göster
                                if e.status == .pending && Date() >= e.scheduledAt {
                                    Divider().padding(.vertical, 6)
                                    moodPicker
                                    ratingRow
                                    promptArea
                                    Group { composer }.id(editorAnchorID)
                                    saveRow(for: e)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            Card {
                                Text("Bugün için planlanmış ping yok.")
                                    .foregroundStyle(Theme.textSec)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, isEditing ? 300 : 0)
                    .transaction { $0.animation = nil }
                }
                .appBackground()
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture { isEditing = false }
                .onChange(of: isEditing) { _, editing in
                    if editing {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(editorAnchorID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            if showSavedToast {
                SaveToast(text: "Kaydedildi")
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Bugün")
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            CircleProgress(progress: progressRatio(), size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("Günün kaydı").font(.headline)
                Text(subtitleText()).font(.caption).foregroundStyle(Theme.textSec)
            }
            Spacer()
            if let allow = vm.entry?.allowEarlyAnswer, allow {
                EarlyBadge()
            }
        }
    }
    
    // YENİ: Bekleme durumunu gösteren yenilikçi kart
    private struct PendingStateView: View {
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accentGradient)
                
                Text("Günün Vibe'ı Yolda...")
                    .font(.title3.weight(.bold))
                
                Text("Bildirim geldiğinde gününü kaydetmek için 10 dakikan olacak.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Mood Picker
    private var moodPicker: some View {
        let items = MoodEmojiCatalog.all
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        let cellHeight: CGFloat = 64
        let visibleRows: CGFloat = 3
        let spacing: CGFloat = 10
        let gridHeight = visibleRows * cellHeight + (visibleRows - 1) * spacing
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bugünkü modun?").font(.headline)
                Spacer()
                if let selected = vm.selectedEmojiVariant {
                    Text(selected).font(.title2).padding(.horizontal, 8).background(Theme.accent.opacity(0.1)).clipShape(Capsule())
                }
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(items) { item in
                        let isSelected = vm.selectedEmojiVariant == item.emoji
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.selectedEmojiVariant = item.emoji
                                vm.selectedEmojiTitle = item.title
                                // GÜNCELLEME 1: Hatalı olan bu satırı siliyoruz.
                                // vm.selectedMood = .happy
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.emoji).font(.system(size: 28)).frame(height: 28)
                                Text(item.title).font(.caption2).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(isSelected ? Theme.accent : Theme.textSec)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: cellHeight)
                            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Theme.accent.opacity(0.15) : Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: gridHeight)
        }
    }
    
    // MARK: - Diğer View'lar (Değişiklik Yok)
    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Günün puanı").font(.headline)
                Spacer()
                Text("\(vm.score)/10")
                    .font(.callout.bold())
                    .foregroundStyle(Theme.accent)
            }
            Slider(value: Binding(
                get: { Double(vm.score) },
                set: { vm.score = Int($0.rounded()) }
            ), in: 1...10, step: 1)
            .tint(Theme.accent)
        }
    }
    private var promptArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bugün nasılsın?").font(.headline)
            Text("Kısaca gününün nasıl geçtiğini, nasıl hissettiğini yaz.")
                .font(.caption)
                .foregroundStyle(Theme.textSec)
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlaceholderTextEditor(text: $vm.text,
                                  placeholder: "Bugün nasılsın? Birkaç cümle yeter…")
            .focused($isEditing)
            .frame(minHeight: 160)
            .padding(10)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disableAutocorrection(true)
            .textInputAutocapitalization(.sentences)
            .id(editorAnchorID)
            
            HStack {
                let count = vm.text.trimmingCharacters(in: .whitespacesAndNewlines).count
                Text("\(count)/500")
                    .font(.caption)
                    .foregroundStyle(count > 500 ? Theme.bad : Theme.textSec)
                Spacer()
                Button {
                    vm.text = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Temizle", systemImage: "eraser")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.accent)
            }
        }
    }
    private func saveRow(for e: DayEntry) -> some View {
        HStack {
            if !e.allowEarlyAnswer {
                Text("Cevap penceresi **\(format(seconds: Int(vm.remaining)))** içinde kapanır.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSec)
            } else {
                Text("Erken cevap modundasın.")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            Button {
                vm.saveNow()
                if vm.lastSaveMessage == "Kaydedildi ✅" {
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showSavedToast = false }
                    }
                }
            } label: {
                Label("Kaydet", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(saveDisabled())
        }
    }
    
    // MARK: - Answered Block
    // GÜNCELLEME 3: Bu fonksiyonu tamamen değiştiriyoruz.
    private func answeredBlock(for e: DayEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(status: e.status)
                Spacer()
                if let s = e.score {
                    Label("\(s)/10", systemImage: "star.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // Tıpkı HistoryView gibi, özel emoji ve başlığı göster
            if let emoji = e.emojiVariant, let title = e.emojiTitle {
                HStack(spacing: 8) {
                    Text(emoji).font(.title)
                    Text(title).font(.headline.weight(.semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let t = e.text, !t.isEmpty {
                Text(t)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Helpers
    private func saveDisabled() -> Bool {
        guard let e = vm.entry else { return true }
        if !e.allowEarlyAnswer {
            let now = Date()
            if now < e.scheduledAt || now > e.expiresAt { return true }
        }
        
        let hasText = !vm.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // GÜNCELLEME 2: Kaydetme koşulu `selectedEmojiVariant`'a göre düzeltildi.
        let hasEmoji = vm.selectedEmojiVariant != nil
        
        if !hasText && !hasEmoji { return true }
        
        if vm.text.count > 500 { return true }
        return false
    }
    
    private func progressRatio() -> CGFloat {
        guard let e = vm.entry else { return 0 }
        let total = max(1, e.expiresAt.timeIntervalSince(e.scheduledAt))
        let left  = max(0, vm.remaining)
        return CGFloat(1 - (left / total))
    }
    
    private func subtitleText() -> String {
        guard let e = vm.entry else { return "Bugün plan yok" }
        switch e.status {
        case .pending:  return "Cevap bekleniyor"
        case .answered: return "Bugünkü kayıt tamam"
        case .missed:   return "Bugünkü kayıt kaçırıldı"
        case .late:     return "Geç cevap"
        }
    }
    
    private func format(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Küçük Bileşenler (CountdownPill, EarlyBadge, CircleProgress, PlaceholderTextEditor, SaveToast)
// (Sende zaten var; aynı şekilde bırakabilirsin)


// MARK: - Küçük Bileşenler

private struct CountdownPill: View {
    let remaining: Int
    var body: some View {
        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.none, value: remaining) // her saniye titreşim olmasın
    }
}

private struct EarlyBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
            Text("Erken cevap")
        }
        .font(.caption.bold())
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Erken cevap modu aktif")
    }
}

private struct CircleProgress: View {
    let progress: CGFloat
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(AngularGradient(gradient: Gradient(colors: [Theme.accent, Theme.good]),
                                        center: .center),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Geri sayım ilerleme")
    }
}

private struct PlaceholderTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Theme.textSec)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            TextEditor(text: $text)
                .opacity(0.98)
                .background(Color.clear)
        }
    }
}

private struct SaveToast: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text(text).font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Geniş emoji + isim kataloğu
enum MoodEmojiCatalog {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let emoji: String
        let title: String
    }
    
    // Farklı hisleri temsil eden geniş bir emoji yelpazesi (her biri kendi ismiyle)
    static let all: [Item] = [
        // Mutlu tonlar
        .init(emoji: "😀", title: "Neşeli"),
        .init(emoji: "😄", title: "Keyifli"),
        .init(emoji: "😁", title: "Güleryüzlü"),
        .init(emoji: "😊", title: "Memnun"),
        .init(emoji: "🙂", title: "Tatlı Gülümseme"),
        .init(emoji: "😎", title: "Kendinden Emin"),
        .init(emoji: "🥳", title: "Kutlama Modu"),
        .init(emoji: "🤗", title: "Sıcak Kalpli"),
        
        // Sakin / rahat tonlar
        .init(emoji: "😌", title: "Sakin"),
        .init(emoji: "🧘‍♀️", title: "Rahatlamış"),
        .init(emoji: "🌿", title: "Doğayla İç İçe"),
        .init(emoji: "🫶", title: "Şükreden"),
        .init(emoji: "💫", title: "Huzurlu"),
        
        // Üzgün tonlar
        .init(emoji: "😔", title: "Üzgün"),
        .init(emoji: "😢", title: "Kırılmış"),
        .init(emoji: "😭", title: "Gözyaşı Döküyor"),
        .init(emoji: "🥺", title: "Kırılgan"),
        .init(emoji: "😞", title: "Hayal Kırıklığı"),
        
        // Stresli / yorgun tonlar
        .init(emoji: "🥱", title: "Uykulu"),
        .init(emoji: "😪", title: "Yorgun"),
        .init(emoji: "😵‍💫", title: "Kafa Karışık"),
        .init(emoji: "😫", title: "Bitkin"),
        .init(emoji: "🤯", title: "Patlamak Üzere"),
        
        // Öfkeli tonlar
        .init(emoji: "😠", title: "Kızgın"),
        .init(emoji: "😡", title: "Çok Sinirli"),
        .init(emoji: "🤬", title: "Öfke Patlaması"),
        .init(emoji: "💢", title: "Gerilmiş"),
        
        // Kaygılı tonlar
        .init(emoji: "😬", title: "Tedirgin"),
        .init(emoji: "😰", title: "Kaygılı"),
        .init(emoji: "😨", title: "Korkmuş"),
        .init(emoji: "🫨", title: "Endişeli"),
        .init(emoji: "😟", title: "İç Çekiyor"),
        
        // Hasta / rahatsız tonlar
        .init(emoji: "🤒", title: "Ateşli"),
        .init(emoji: "🤕", title: "Ağrılı"),
        .init(emoji: "🤧", title: "Üşütmüş"),
        .init(emoji: "🥴", title: "Sersemlemiş"),
        .init(emoji: "😷", title: "Maskeli Hasta"),
        
        // Eğlenceli / deli dolu tonlar
        .init(emoji: "🤪", title: "Deli Doluyum"),
        .init(emoji: "😜", title: "Yaramaz"),
        .init(emoji: "😋", title: "Lezzetli Anlar"),
        .init(emoji: "🤩", title: "Aşırı Heyecanlı"),
        .init(emoji: "✨", title: "Parlıyorum"),
        .init(emoji: "🙃", title: "Tersine Gülen"),
        .init(emoji: "😏", title: "Kendine Güvenen"),
        
        // Nötr / kararsız
        .init(emoji: "😐", title: "Nötr"),
        .init(emoji: "😶", title: "Sessiz"),
        .init(emoji: "🤔", title: "Düşünceli"),
        .init(emoji: "🫤", title: "Kararsız"),
        .init(emoji: "😑", title: "İlgisiz")
    ]
}
