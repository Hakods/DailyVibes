//
//  CoachView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 16.10.2025.
//

import SwiftUI

struct CoachView: View {
    @StateObject private var vm: CoachVM
    
    @EnvironmentObject var store: StoreService
    @EnvironmentObject var languageSettings: LanguageSettings
    @EnvironmentObject var themeManager: ThemeManager
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showSettings = false
    
    init(store: StoreService) {
        _vm = StateObject(wrappedValue: CoachVM(store: store))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                if vm.chatMessages.count == 1 && !vm.chatMessages[0].isFromUser {
                                    WelcomeCardView()
                                }
                                
                                ForEach(vm.chatMessages) { message in
                                    MessageView(message: message)
                                }
                                
                                if vm.isLoading && vm.chatMessages.last?.isFromUser == true {
                                    HStack {
                                        LoadingDotsView()
                                            .padding(12)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                        Spacer()
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding()
                            .padding(.bottom, 100)
                            .onTapGesture { isTextFieldFocused = false }
                            .onChange(of: vm.chatMessages.count) { _, _ in scrollToBottom(proxy: proxy) }
                            .onChange(of: vm.chatMessages.last?.text) { _, _ in scrollToBottom(proxy: proxy) }
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                    
                    if vm.subscriptionReady && !vm.isProCached && vm.freeMessagesRemaining <= 0 {
                        PaywallPromptView(onTap: { vm.showPaywall = true })
                    } else {
                        ChatInputBar(
                            vm: vm,
                            userQuestion: $vm.userQuestion,
                            isLoading: $vm.isLoading,
                            isTextFieldFocused: $isTextFieldFocused,
                            onSend: {
                                vm.askQuestion()
                                isTextFieldFocused = false
                            },
                            onCancel: {
                                vm.cancel()
                            }
                        )
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("coach.nav.title"))
            .task {
                await store.refreshEntitlements()
            }
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
            }
            .sheet(isPresented: $vm.showPaywall) {
                PaywallView(vm: PaywallVM(store: self.store))
                    .environmentObject(self.store)
                    .environmentObject(self.themeManager)
            }
            .sheet(isPresented: $showSettings) {
                CoachSettingsView(vm: vm)
            }
            .onAppear {
                vm.updateLanguage(langCode: languageSettings.selectedLanguageCode)
            }
            .onChange(of: languageSettings.selectedLanguageCode) { _, newLangCode in
                vm.updateLanguage(langCode: newLangCode)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessageID = vm.chatMessages.last?.id else { return }
        withAnimation(.spring()) {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }
}

// MARK: - Alt Bileşenler (Değişiklik yok)

private struct PaywallPromptView: View {
    var onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 12) {
                Text(LocalizedStringKey("coach.paywall.title"))
                    .font(.headline)
                
                Button(LocalizedStringKey("coach.paywall.button")) {
                    onTap()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(.regularMaterial)
    }
}

// MARK: - Alt Bileşenler

// YENİ: Kullanıcıyı karşılayan ve örnek sorular sunan kart
private struct WelcomeCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accentGradient)
                Text(LocalizedStringKey("coach.welcome.title"))
                    .font(.title2.bold())
            }
            
            Text(LocalizedStringKey("coach.welcome.body"))
                .font(.subheadline)
                .foregroundStyle(Theme.textSec)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("coach.welcome.examples.title")).font(.headline)
                Text(LocalizedStringKey("coach.welcome.examples.q1"))
                Text(LocalizedStringKey("coach.welcome.examples.q2"))
                Text(LocalizedStringKey("coach.welcome.examples.q3"))
            }
            .font(.footnote)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// YENİ: Daha şık ve fonksiyonel bir input bar
private struct ChatInputBar: View {
    @ObservedObject var vm: CoachVM
    @Binding var userQuestion: String
    @Binding var isLoading: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    
    var onSend: () -> Void
    var onCancel: () -> Void
    
    private var placeholder: String {
        let key = isLoading ? "coach.input.placeholder.loading" : "coach.input.placeholder.default"
        return NSLocalizedString(key, bundle: vm.currentBundle, comment: "Chat input placeholder")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Metin giriş alanı
                TextField(placeholder, text: $userQuestion, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused(isTextFieldFocused)
                    .disabled(isLoading)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .lineLimit(1...5)
                
                // Sağ taraftaki buton alanı (Dinamik olarak değişecek)
                ZStack {
                    if isLoading {
                        // Eğer yükleniyorsa, "Durdur" butonunu göster
                        Button(role: .destructive, action: onCancel) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Eğer yüklenmiyorsa, "Gönder" butonunu göster
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundStyle(userQuestion.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.5) : Theme.accent)
                        }
                        .disabled(userQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 30, height: 30) // Butonların kapladığı alan sabit kalsın
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .animation(.default, value: isLoading)
    }
}

// YENİ: AI Koçunun ayarlarını yöneteceğimiz ekran
private struct CoachSettingsView: View {
    @ObservedObject var vm: CoachVM
    @Environment(\.dismiss) var dismiss
    
    private var creativeDescription: String {
        let key = vm.isCreative ? "coach.settings.creative.desc" : "coach.settings.balanced.desc"
        return NSLocalizedString(key, bundle: vm.currentBundle, comment: "Creative toggle description")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("coach.settings.creativity.title")) {
                    Toggle(LocalizedStringKey("coach.settings.creative.toggle"), isOn: $vm.isCreative)
                    
                    Text(creativeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.1), value: vm.isCreative)
                }
                
                Section(LocalizedStringKey("coach.settings.length.title")) {
                    Slider(value: $vm.shortnessLevel, in: 0.0...1.0)
                    HStack {
                        Text(LocalizedStringKey("coach.settings.length.detailed")).font(.caption)
                        Spacer()
                        Text(LocalizedStringKey("coach.settings.length.concise")).font(.caption)
                    }
                }
                
                Section(LocalizedStringKey("coach.settings.speed.title")) {
                    Slider(value: $vm.typingSpeed, in: 0.0...0.05)
                    HStack {
                        Text(LocalizedStringKey("coach.settings.speed.fast")).font(.caption)
                        Spacer()
                        Text(LocalizedStringKey("coach.settings.speed.slow")).font(.caption)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("coach.settings.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(LocalizedStringKey("button.done")) {
                    dismiss()
                }
            }
        }
    }
}

// Mevcut Bileşenler (Değişiklik yok)
struct LoadingDotsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .padding(.horizontal, 5)
    }
}
struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Theme.accent.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 300, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 300, alignment: .leading)
                Spacer()
            }
        }
        .id(message.id)
    }
}
