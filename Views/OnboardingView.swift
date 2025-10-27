//
//  OnboardingView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 27.10.2025.
//

import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
    let isPermissionStep: Bool
    let isFinalStep: Bool
}

private let onboardingSteps: [OnboardingStep] = [
    .init(imageName: "figure.mind.and.body",
          title: "İç Dünyanı Anlamaya Bir Adım At",
          description: "Günlük küçük kayıtlarla duygusal desenlerini keşfet, kendini daha iyi tanı.",
          isPermissionStep: false, isFinalStep: false),
    
    .init(imageName: "pencil.and.scribble",
          title: "Günde Birkaç Dakika Yeterli",
          description: "Modunu seç, gününe puan ver ve aklındakileri kısaca not al. Bu kadar basit!",
          isPermissionStep: false, isFinalStep: false),
    
    .init(imageName: "bell.badge.fill",
          title: "Anı Kaçırma Diye Hatırlatırız",
          description: "Günün Vibe'ını unutmaman için rastgele bir 'ping' ile sana nazikçe sesleneceğiz (10:00-22:00).",
          isPermissionStep: false, isFinalStep: false),
    
    .init(imageName: "brain.head.profile.fill",
          title: "Sana Özel İçgörüler",
          description: "AI Koçun, *senin* kayıtlarını analiz ederek genel tavsiyeler yerine kişisel yorumlar ve cevaplar sunar.",
          isPermissionStep: false, isFinalStep: false),
    
    .init(imageName: "bell.fill",
          title: "Hatırlatmalar İçin İzin",
          description: "Sana 'ping' gönderebilmemiz için bildirimlere izin vermen gerekiyor. Söz, spam yok!",
          isPermissionStep: true, isFinalStep: false),
    
    .init(imageName: "figure.walk.arrival",
          title: "Keşif Yolculuğun Başlıyor!",
          description: "Her şey hazır. Kendini daha iyi anlamak için ilk adımını at.",
          isPermissionStep: false, isFinalStep: true)
]

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var notificationService: NotificationService
    @State private var currentStepIndex = 0
    @State private var notificationRequested = false
    @State private var notificationGranted = false
    @Namespace var namespace
    
    var currentStep: OnboardingStep { onboardingSteps[currentStepIndex] }
    
    var body: some View {
        ZStack {
            AnimatedAuroraBackground()
                .ignoresSafeArea()
                .zIndex(-1)
            
            VStack {
                Spacer()
                
                Group {
                    if currentStep.isPermissionStep {
                        NotificationPermissionStepView(
                            step: currentStep,
                            notificationService: notificationService,
                            notificationRequested: $notificationRequested,
                            notificationGranted: $notificationGranted
                        )
                    } else {
                        OnboardingStepView(step: currentStep)
                    }
                }
                .padding(.horizontal, 30)
                .id(currentStep.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity))
                )
                
                
                Spacer()
                
                HStack(spacing: 12) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStepIndex ? Theme.accent : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(index == currentStepIndex ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStepIndex)
                    }
                }
                .padding(.bottom, 16)
                
                Button {
                    handleNextButtonTap()
                } label: {
                    Text(currentStep.isFinalStep ? "Başla!" : "İleri")
                        .fontWeight(.bold)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .disabled(currentStep.isPermissionStep && !notificationRequested)
            }
            .animation(.easeInOut(duration: 0.4), value: currentStepIndex)
        }
        .onAppear {
            Task {
                notificationGranted = await notificationService.checkAuthStatus()
                if notificationGranted { notificationRequested = true }
            }
        }
    }
    
    func handleNextButtonTap() {
        if currentStep.isPermissionStep && !notificationGranted {
            if notificationRequested {
                if currentStepIndex < onboardingSteps.count - 1 {
                    currentStepIndex += 1
                }
            } else {
            }
        } else if currentStep.isFinalStep {
            hasCompletedOnboarding = true
        } else {
            if currentStepIndex < onboardingSteps.count - 1 {
                currentStepIndex += 1
            }
        }
    }
}

struct OnboardingStepView: View {
    let step: OnboardingStep
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: step.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .foregroundStyle(Theme.accentGradient)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
            
            VStack(spacing: 15) {
                Text(step.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(Theme.textSec)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
            }
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 50, damping: 10).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}

struct NotificationPermissionStepView: View {
    let step: OnboardingStep
    @ObservedObject var notificationService: NotificationService
    @Binding var notificationRequested: Bool
    @Binding var notificationGranted: Bool
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: step.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(notificationGranted ? Theme.good : Theme.accent)
                .symbolEffect(.variableColor.iterative.reversing, value: notificationGranted)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)
            
            VStack(spacing: 15) {
                Text(step.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(Theme.textSec)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
            }
            
            if !notificationGranted {
                Button {
                    Task {
                        notificationRequested = true
                        notificationGranted = await notificationService.requestAuth()
                    }
                } label: {
                    Label("Bildirimlere İzin Ver", systemImage: "bell.fill")
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                        .frame(maxWidth: 250)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)
                .disabled(notificationRequested)
                .padding(.top)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
                .transition(.opacity.combined(with: .scale))
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("İzin verildi!")
                }
                .foregroundStyle(Theme.good)
                .padding(.top)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 50, damping: 10).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}
