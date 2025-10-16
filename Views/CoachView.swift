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

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedAuroraBackground()
                
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(vm.chatMessages) { message in
                                    MessageView(message: message)
                                }
                                
                                // GÜNCELLEME: Yüklenirken dalgalanan noktaları göster
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
                            .onTapGesture { isTextFieldFocused = false }
                            .onChange(of: vm.chatMessages.count) { _, _ in
                                scrollToBottom(proxy: proxy)
                            }
                            .onChange(of: vm.chatMessages.last?.text) { _, _ in
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                    
                    HStack {
                        TextField("Koçuna bir soru sor...", text: $vm.userQuestion)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                        
                        Button {
                            vm.askQuestion()
                            isTextFieldFocused = false
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(vm.userQuestion.isEmpty || vm.isLoading)
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Koçun")
            .contentShape(Rectangle())
            .onTapGesture { isTextFieldFocused = false }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessageID = vm.chatMessages.last?.id else { return }
        withAnimation {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }
}

// YENİ: Dalgalanan yükleme animasyonu
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
        .padding(.horizontal, 5) // Metinle aynı hizada durması için
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
