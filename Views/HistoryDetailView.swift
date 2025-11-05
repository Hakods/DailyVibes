import SwiftUI

struct HistoryDetailView: View {
    let entry: DayEntry
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var languageSettings: LanguageSettings
    
    private var currentLocale: Locale {
        languageSettings.computedLocale ?? Locale.autoupdatingCurrent
    }

    private var fullDateTitle: String {
        let df = DateFormatter()
        df.locale = currentLocale
        df.dateStyle = .full
        return df.string(from: entry.day)
    }
    
    private var moodEmoji: String? { entry.emojiVariant }
    private var moodTitleKey: String? { entry.emojiTitle }
    
    var body: some View {
        ZStack {
            // Arka plan aynı kalıyor
            AnimatedAuroraBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. ANA BİLGİ BÖLÜMÜ (Başlık ve Emoji)
                    // Bu bölümü kart dışına alarak daha ferah ve odaklı hale getirdik.
                    VStack(spacing: 12) {
                        Text(fullDateTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        if let emo = moodEmoji, let titleKey = moodTitleKey {
                            Text(emo)
                                .font(.system(size: 90))
                            
                            Text(LocalizedStringKey(titleKey))
                                .font(.title.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        
                        StatusBadge(status: entry.status)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    

                    // 2. DETAYLAR KARTI (Puan ve Zaman Aralığı)
                    // İkonlar ve daha düzenli bir yerleşimle bilgileri grupladık.
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            if let score = entry.score {
                                HStack(spacing: 12) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Theme.warn)
                                    
                                    Text("Günün Puanı")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(score)/10")
                                        .font(.headline.weight(.bold))
                                }
                            }

                            // Puan ve zaman arasında görsel bir ayırıcı
                            if entry.score != nil {
                                Divider()
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "hourglass.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.secondary)
                                
                                Text("Cevap Aralığı")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(entry.scheduledAt.formatted(date: .omitted, time: .shortened)) - \(entry.expiresAt.formatted(date: .omitted, time: .shortened))")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    // 3. NOT KARTI
                    // Notu daha belirgin hale getirdik.
                    if let text = entry.text, !text.isEmpty {
                        Card {
                             VStack(alignment: .leading, spacing: 12) {
                                Label("Notun", systemImage: "text.quote")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textSec)
                                
                                Text(text)
                                    .font(.body)
                                    .lineSpacing(5) // Satır aralığını artırarak okunabilirliği iyileştirdik.
                                    .frame(maxWidth: .infinity, alignment: .leading)
                             }
                        }
                    } else {
                        // Not yoksa boş durumu gösteren bir kart
                        Card {
                            Label("Bu gün için not eklenmemiş.", systemImage: "text.badge.xmark")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundStyle(Theme.textSec)
                                .padding(.vertical)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Kayıt Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            themeManager.update(for: entry)
        }
        .onDisappear {
            themeManager.update(for: nil)
        }
    }
}
