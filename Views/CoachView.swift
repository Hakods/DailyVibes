//
//  CoachView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 16.10.2025.
//

import SwiftUI

struct CoachView: View {
    @StateObject private var vm = CoachVM()
    @FocusState private var isTextFieldFocused: Bool
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                VStack(spacing: 0) {
                    // Sohbet Balonları
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                // YENİ: Başlangıçta kullanıcıyı yönlendiren bir kart
                                if vm.chatMessages.count <= 1 {
                                    WelcomeCardView()
                                }
                                
                                ForEach(vm.chatMessages) { message in
                                    MessageView(message: message)
                                }
                                
                                if vm.isLoading {
                                    HStack {
                                        LoadingDotsView()
                                            .padding(12)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            // GÜNCELLEME: Input bar'ın altında daha fazla boşluk bırakmak için padding artırıldı
                            .padding(.bottom, 100)
                            .onTapGesture { isTextFieldFocused = false }
                            .onChange(of: vm.chatMessages.count) { _, _ in scrollToBottom(proxy: proxy) }
                            .onChange(of: vm.chatMessages.last?.text) { _, _ in scrollToBottom(proxy: proxy) }
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                    
                    // YENİ: Daha şık bir soru yazma alanı
                    ChatInputBar(
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
            .navigationTitle("AI Koçun")
            .toolbar {
                // YENİ: Ayarlar butonu
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
            .sheet(isPresented: $showSettings) {
                // YENİ: Ayarlar ekranı
                CoachSettingsView(vm: vm)
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

// MARK: - Alt Bileşenler

// YENİ: Kullanıcıyı karşılayan ve örnek sorular sunan kart
private struct WelcomeCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accentGradient)
                Text("Vibe Koçu'na Hoş Geldin!")
                    .font(.title2.bold())
            }
            
            Text("Son zamanlardaki kayıtlarını analiz ederek sana özel içgörüler sunabilirim. Merak ettiklerini sormaktan çekinme.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSec)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Örnek Sorular:").font(.headline)
                Text("• Son zamanlarda neden yorgun hissediyorum?")
                Text("• En mutlu olduğum anlar hangileriydi?")
                Text("• Stresimin ana kaynağı ne gibi duruyor?")
            }
            .font(.footnote)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// YENİ: Daha şık ve fonksiyonel bir input bar
private struct ChatInputBar: View {
    @Binding var userQuestion: String
    @Binding var isLoading: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    
    var onSend: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Metin giriş alanı
                TextField(isLoading ? "Cevap bekleniyor..." : "Koçuna bir soru sor...", text: $userQuestion, axis: .vertical)
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
    
    var body: some View {
        NavigationView {
            Form {
                Section("Yaratıcılık") {
                    Toggle("Geçmişe Daha Az Bağlı Kal", isOn: $vm.isCreative)
                    Text(vm.isCreative ? "Koç, verilerini ilham kaynağı olarak kullanır ve daha özgür cevaplar verir." : "Koç, cevaplarını büyük ölçüde girdiğin kayıtlara dayandırır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Cevap Uzunluğu") {
                    Slider(value: $vm.shortnessLevel, in: 0.0...1.0)
                    HStack {
                        Text("Detaylı").font(.caption)
                        Spacer()
                        Text("Kısa ve Öz").font(.caption)
                    }
                }
                
                Section("Yazma Hızı") {
                    Slider(value: $vm.typingSpeed, in: 0.0...0.05)
                    HStack {
                        Text("Hızlı").font(.caption)
                        Spacer()
                        Text("Yavaş").font(.caption)
                    }
                }
            }
            .navigationTitle("Koç Ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Bitti") {
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
