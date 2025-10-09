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

    struct Msg: Identifiable { let id: UUID; let text: String }

    var body: some View {
        ZStack(alignment: .bottom) {
            AnimatedAuroraBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let e = vm.entry {
                        Card {
                            topRow(for: e)

                            Divider().padding(.vertical, 6)

                            if e.status == .pending {
                                // 1) Mood + 2) Puan + 3) Metin + 4) Kaydet
                                moodPicker
                                ratingRow
                                promptArea
                                composer
                                saveRow(for: e)
                            } else {
                                answeredBlock(for: e)
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
                .transaction { $0.animation = nil } // yeniden layout’ta zıplamayı azaltır
            }
            .appBackground()
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { isEditing = false } // ekrana dokununca klavye kapanır

            // mini toast
            if showSavedToast {
                SaveToast(text: "Kaydedildi")
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle("Bugün")
        .alert(item: Binding(
            get: { vm.lastSaveMessage.map { Msg(id: UUID(), text: $0) } },
            set: { _ in vm.lastSaveMessage = nil }
        )) { msg in
            Alert(title: Text(msg.text))
        }
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

    // MARK: - Top Row
    private func topRow(for e: DayEntry) -> some View {
        HStack(spacing: 10) {
            Text("⏰")
            VStack(alignment: .leading) {
                Text("Planlanan saat")
                    .font(.subheadline).foregroundStyle(Theme.textSec)
                Text(e.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.title3.bold())
            }
            Spacer()
            if e.status == .pending {
                CountdownPill(remaining: Int(vm.remaining))
            } else {
                StatusBadge(status: e.status)
            }
        }
    }

    // MARK: - Mood Picker
    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bugünkü modun?")
                .font(.headline)

            let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Mood.allCases) { mood in
                    let selected = vm.selectedMood == mood
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.selectedMood = selected ? nil : mood
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Text(mood.emoji).font(.system(size: 28))
                            Text(mood.title)
                                .font(.caption2)
                                .foregroundStyle(selected ? Theme.accent : Theme.textSec)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected ? Theme.accent.opacity(0.15) : Theme.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Theme.accent : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Rating Row
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

    // MARK: - Prompt + Composer
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

    // MARK: - Save Row
    private func saveRow(for e: DayEntry) -> some View {
        HStack {
            if !(vm.entry?.allowEarlyAnswer ?? false) {
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
            } label: {
                Label("Kaydet", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(saveDisabled())
        }
    }

    // MARK: - Answered Block (mood + score göster)
    private func answeredBlock(for e: DayEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusBadge(status: e.status)
                Spacer()
                if let s = e.score {
                    Label("\(s)/10", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let m = e.mood {
                HStack(spacing: 6) {
                    Text(m.emoji)
                    Text(m.title).font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let t = e.text, !t.isEmpty {
                Text(t)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if e.mood == nil && e.score == nil {
                Text("Bu gün için kayıt yok.")
                    .foregroundStyle(Theme.textSec)
            }
        }
    }

    // MARK: - Helpers
    private func saveDisabled() -> Bool {
        guard let e = vm.entry else { return true }

        // pencere kontrolü
        if !(e.allowEarlyAnswer ?? false) {
            let now = Date()
            if now < e.scheduledAt { return true }
            if now > e.expiresAt { return true }
        }

        // içerik kontrolü: en azından mood veya metin olsun
        let hasText = !vm.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMood = vm.selectedMood != nil
        if !hasText && !hasMood { return true }

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
