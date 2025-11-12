//
//  TodayView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import SwiftUI

struct TodayView: View {
    @StateObject private var vm = TodayVM()
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isEditingTextEditor: Bool
    @State private var showSavedToast = false
    @Namespace private var anim
    private let editorAnchorID = "EDITOR_ANCHOR"
    
    @State private var unmetConditions: [String] = []
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AnimatedAuroraBackground()
                .sheet(isPresented: $vm.showBreathingExercise) { BreathingExerciseView()
                        .environmentObject(themeManager)
                }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        
                        if let e = vm.entry {
                            entryCardContent(for: e, proxy: proxy)
                        } else {
                            Card {
                                HStack(spacing: 10) {
                                    Image(systemName: "hourglass.bottomhalf.filled")
                                        .foregroundStyle(Theme.secondary)
                                    Text("Bugünkü ping henüz gelmedi.")
                                        .foregroundStyle(Theme.textSec)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)
                            }
                        }
                        if vm.showMindfulnessCard {
                            mindfulnessSection
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, isEditingTextEditor ? 300 : 0)
                    .transaction { $0.animation = nil }
                }
                .appBackground()
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture { isEditingTextEditor = false }
                .onChange(of: isEditingTextEditor) { _, editing in handleFocusChange(editing: editing, proxy: proxy, anchor: editorAnchorID) }
            }
            
            if showSavedToast {
                SaveToast(textKey: "save.toast.success")
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Bugün")
        .onChange(of: vm.entry, initial: true) { _, newEntry in
            themeManager.update(for: newEntry)
        }
        .animation(.easeInOut, value: vm.showMindfulnessCard)
    }
    
    @ViewBuilder
    private func entryCardContent(for e: DayEntry, proxy: ScrollViewProxy) -> some View {
        Card {
            if e.status == .pending {
                if vm.isAnswerWindowActive {
                    topRow(for: e)
                    Divider().padding(.vertical, 6)
                    moodPicker
                    ratingRow
                    promptArea
                    Group { composer() }.id(editorAnchorID)
                    saveRow(for: e)
                } else {
                    PendingStateView()
                }
            } else {
                answeredBlock(for: e) // Günün Sorusu olmadan
            }
        }
        .animation(.default, value: vm.isAnswerWindowActive)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var mindfulnessSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Bir Mola Ver", systemImage: "figure.mind.and.body")
                    .font(.headline)
                
                Text("Yoğun hissediyorsan, kısa bir nefes egzersizi an'a dönmene yardımcı olabilir.")
                    .font(.caption)
                    .foregroundStyle(Theme.warn)
                
                Button { vm.toggleBreathingExercise() } label: {
                    Label("Nefes Egzersizini Başlat", systemImage: "wind")
                }
                .buttonStyle(SubtleButtonStyle())
                .padding(.top, 5)
            }
        }
    }
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            CircleProgress(progress: progressRatio(), size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("Günün kaydı").font(.headline)
                Text(LocalizedStringKey(subtitleKey())).font(.caption).foregroundStyle(Theme.textSec)
            }
            Spacer()
            if let allow = vm.entry?.allowEarlyAnswer, allow {
                EarlyBadge()
            }
        }
    }
    
    private func topRow(for e: DayEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            
            VStack(alignment: .leading) {
                Text("Vibe'ını kaydetme zamanı!")
                    .font(.headline)
                Text("Kalan süre")
                    .font(.subheadline).foregroundStyle(Theme.textSec)
            }
            Spacer()
            if e.status == .pending {
                CountdownPill(remaining: Int(vm.remaining))
            }
        }
    }
    
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
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.emoji).font(.system(size: 28)).frame(height: 28)
                                Text(LocalizedStringKey(item.title)).font(.caption2).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(isSelected ? Theme.accent : Theme.textSec)
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

    private func composer() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PlaceholderTextEditor(text: $vm.text,
                                              placeholder: vm.dynamicPlaceholder,
                                              isFocused: $isEditingTextEditor)
            .frame(minHeight: 100)
            .padding(10)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disableAutocorrection(true)
            .textInputAutocapitalization(.sentences)
            
            HStack {
                let count = vm.text.trimmingCharacters(in: .whitespacesAndNewlines).count
                Text("\(count)/500")
                    .font(.caption)
                    .foregroundStyle(count > 500 ? Theme.bad : Theme.textSec)
                Spacer()
                Button {
                    vm.text = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: { Label("Temizle", systemImage: "eraser") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func saveRow(for e: DayEntry) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !unmetConditions.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(unmetConditions, id: \.self) { key in
                        Text(LocalizedStringKey(key))
                    }
                }
                    .font(.caption)
                    .foregroundStyle(Theme.warn)
                    .multilineTextAlignment(.trailing)
                    .transition(.opacity)
            }
            
            HStack {
                Text("Cevap penceresi **\(format(seconds: Int(vm.remaining)))** içinde kapanır.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSec)
                Spacer()
                Button {
                    vm.saveNow()
                    if vm.lastSaveMessage == "save.success" {
                        withAnimation { showSavedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showSavedToast = false }
                        }
                    }
                } label: {
                    Label(LocalizedStringKey("save.button.save"), systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(saveDisabled())
            }
        }
        .onChange(of: vm.selectedEmojiVariant) { _, _ in updateSaveButtonState() }
        .onChange(of: vm.text) { _, _ in updateSaveButtonState() }
        .onAppear { updateSaveButtonState() }
    }
   
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
            if let emoji = e.emojiVariant, let title = e.emojiTitle {
                HStack(spacing: 8) {
                    Text(emoji).font(.title)
                    Text(LocalizedStringKey(title)).font(.headline.weight(.semibold))
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
            } else {
                Text("Bu gün için not eklenmemiş.")
                    .foregroundStyle(Theme.textSec)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            }
        }
    }
    
    private func handleFocusChange(editing: Bool, proxy: ScrollViewProxy, anchor: String) {
        guard editing else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(anchor, anchor: .bottom)
            }
        }
    }
    
    private func saveDisabled() -> Bool {
        !unmetConditions.isEmpty
    }
    
    private func updateSaveButtonState() {
        var conditions: [String] = []
        
        // GÜNCELLEME: Türkçe metinler yerine çeviri anahtarları kullanılıyor
        if vm.selectedEmojiVariant == nil {
            conditions.append("validation.selectMood")
        }
        
        if vm.text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            conditions.append("validation.minChars")
        }
        
        if vm.text.trimmingCharacters(in: .whitespacesAndNewlines).count > 500 {
            conditions.append("validation.maxChars")
        }
        
        withAnimation(.easeInOut) {
            self.unmetConditions = conditions
        }
    }
    
    private func progressRatio() -> CGFloat {
        guard let e = vm.entry else { return 0 }
        let total = max(1, e.expiresAt.timeIntervalSince(e.scheduledAt))
        let left  = max(0, vm.remaining)
        return CGFloat(1 - (left / total))
    }
    
    private func subtitleKey() -> String {
        guard let e = vm.entry else { return "today.subtitle.noPlan" }
        switch e.status {
        case .pending:  return "today.subtitle.pending"
        case .answered: return "today.subtitle.answered"
        case .missed:   return "today.subtitle.missed"
        case .late:     return "today.subtitle.late"
        }
    }
    
    private func format(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct CountdownPill: View {
    let remaining: Int
    var body: some View {
        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.none, value: remaining)
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
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($isFocused)
                .background(Theme.bg)
                .accessibilityLabel(Text(placeholder))

            if text.isEmpty {
                Text(LocalizedStringKey(placeholder))
                    .foregroundStyle(Theme.textSec)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .onTapGesture {
                        isFocused = true
                    }
                    .allowsHitTesting(!isFocused && text.isEmpty)
                    .accessibilityHidden(true)
            }
        }
         .contentShape(Rectangle())
         .onTapGesture {
             isFocused = true
         }
    }
}

struct BreathingExerciseView: View {
    @State private var scale: CGFloat = 0.5
    @State private var text = "breath.in"
    @Environment(\.dismiss) var dismiss
    
    let animationDuration = 4.0
    
    var body: some View {
        ZStack {
            Theme.AnimatedBackground().opacity(0.7)
            
            VStack(spacing: 40) {
                Text(LocalizedStringKey("breath.title"))
                    .font(.title2.bold())
                
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .opacity(0.3)
                    
                    Circle()
                        .fill(Theme.accentGradient)
                        .scaleEffect(scale)
                }
                .frame(width: 200, height: 200)
                
                Text(LocalizedStringKey(text))
                    .font(.headline)
                    .animation(nil, value: text)
                
                Button(LocalizedStringKey("Bitir")) {
                    dismiss()
                }
                .buttonStyle(SubtleButtonStyle())
                .padding(.top, 20)
            }
            .padding()
        }
        .onAppear(perform: startAnimation)
    }
    
    func startAnimation() {
        scale = 0.5
        text = "breath.in"
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            scale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            text = "breath.hold"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 2) {
            text = "breath.out"
            withAnimation(.easeInOut(duration: animationDuration)) {
                scale = 0.5
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 3) {
            startAnimation()
        }
    }
}

private struct SaveToast: View {
    let textKey: LocalizedStringKey
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text(textKey).font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        .accessibilityAddTraits(.isStaticText)
    }
}

enum MoodEmojiCatalog {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let emoji: String
        let title: String // Bu artık bir anahtar (key)
    }
    
    static let all: [Item] = [
        // Mutlu tonlar
        .init(emoji: "😀", title: "emoji.joyful"),
        .init(emoji: "😄", title: "emoji.cheerful"),
        .init(emoji: "😁", title: "emoji.smiling"),
        .init(emoji: "😊", title: "emoji.pleased"),
        .init(emoji: "🙂", title: "emoji.slightSmile"),
        .init(emoji: "😎", title: "emoji.confident"),
        .init(emoji: "🥳", title: "emoji.celebrating"),
        .init(emoji: "🤗", title: "emoji.warmHearted"),
        
        // Sakin / rahat tonlar
        .init(emoji: "😌", title: "emoji.calm"),
        .init(emoji: "🧘‍♀️", title: "emoji.relaxed"),
        .init(emoji: "🌿", title: "emoji.inNature"),
        .init(emoji: "🫶", title: "emoji.grateful"),
        .init(emoji: "💫", title: "emoji.peaceful"),
        
        // Üzgün tonlar
        .init(emoji: "😔", title: "emoji.sad"),
        .init(emoji: "😢", title: "emoji.hurt"),
        .init(emoji: "😭", title: "emoji.crying"),
        .init(emoji: "🥺", title: "emoji.vulnerable"),
        .init(emoji: "😞", title: "emoji.disappointed"),
        
        // Stresli / yorgun tonlar
        .init(emoji: "🥱", title: "emoji.sleepy"),
        .init(emoji: "😪", title: "emoji.tired"),
        .init(emoji: "😵‍💫", title: "emoji.confused"),
        .init(emoji: "😫", title: "emoji.exhausted"),
        .init(emoji: "🤯", title: "emoji.aboutToBurst"),
        
        // Öfkeli tonlar
        .init(emoji: "😠", title: "emoji.angry"),
        .init(emoji: "😡", title: "emoji.furious"),
        .init(emoji: "🤬", title: "emoji.enraged"),
        .init(emoji: "💢", title: "emoji.tense"),
        
        // Kaygılı tonlar
        .init(emoji: "😬", title: "emoji.uneasy"),
        .init(emoji: "😰", title: "emoji.anxious"),
        .init(emoji: "😨", title: "emoji.scared"),
        .init(emoji: "🫨", title: "emoji.worried"),
        .init(emoji: "😟", title: "emoji.sighing"),
        
        // Hasta / rahatsız tonlar
        .init(emoji: "🤒", title: "emoji.feverish"),
        .init(emoji: "🤕", title: "emoji.inPain"),
        .init(emoji: "🤧", title: "emoji.feelingSick"),
        .init(emoji: "🥴", title: "emoji.woozy"),
        .init(emoji: "😷", title: "emoji.sickMasked"),
        
        // Eğlenceli / deli dolu tonlar
        .init(emoji: "🤪", title: "emoji.goofy"),
        .init(emoji: "😜", title: "emoji.mischievous"),
        .init(emoji: "😋", title: "emoji.yummy"),
        .init(emoji: "🤩", title: "emoji.excited"),
        .init(emoji: "✨", title: "emoji.sparkling"),
        .init(emoji: "🙃", title: "emoji.silly"),
        .init(emoji: "😏", title: "emoji.smug"),
        
        // Nötr / kararsız
        .init(emoji: "😐", title: "emoji.neutral"),
        .init(emoji: "😶", title: "emoji.silent"),
        .init(emoji: "🤔", title: "emoji.thoughtful"),
        .init(emoji: "🫤", title: "emoji.undecided"),
        .init(emoji: "😑", title: "emoji.indifferent")
    ]
}
