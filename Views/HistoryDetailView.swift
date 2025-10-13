import SwiftUI

struct HistoryDetailView: View {
    let entry: DayEntry

    private var titleTR: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateStyle = .full // Daha detaylı bir tarih formatı
        return df.string(from: entry.day)
    }

    private var moodEmoji: String? {
        entry.emojiVariant ?? entry.mood?.emoji
    }

    private var moodTitle: String? {
        entry.emojiTitle ?? entry.mood?.title
    }

    var body: some View {
        ZStack {
            AnimatedAuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Tarih ve Durum Kartı
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(titleTR)
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                            
                            HStack(spacing: 12) {
                                Label(entry.scheduledAt.formatted(date: .omitted, time: .shortened), systemImage: "bell")
                                Text("→")
                                Text(entry.expiresAt.formatted(date: .omitted, time: .shortened))
                                    .foregroundStyle(Theme.textSec)
                                Spacer()
                                StatusBadge(status: entry.status)
                            }
                            .font(.subheadline)
                        }
                    }

                    // Mod ve Puan Kartı
                    if moodEmoji != nil || entry.score != nil {
                        Card {
                            VStack(alignment: .leading, spacing: 16) {
                                if let emo = moodEmoji, let lbl = moodTitle {
                                    HStack(spacing: 15) {
                                        Text(emo)
                                            .font(.system(size: 48))
                                        VStack(alignment: .leading) {
                                            Text("Modun")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSec)
                                            Text(lbl)
                                                .font(.title3.weight(.semibold))
                                        }
                                    }
                                }

                                if let s = entry.score {
                                    if moodEmoji != nil { Divider() }
                                    HStack(spacing: 15) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Theme.warn)
                                        VStack(alignment: .leading) {
                                            Text("Günün Puanı")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSec)
                                            Text("\(s)/10")
                                                .font(.title3.weight(.semibold))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Not Kartı
                    Card {
                         VStack(alignment: .leading, spacing: 8) {
                            Text("Notun")
                                .font(.headline)
                                .foregroundStyle(Theme.textSec)
                                .padding(.bottom, 4)
                            
                            if let t = entry.text, !t.isEmpty {
                                Text(t)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("Bu gün için metin eklenmemiş.")
                                    .foregroundStyle(Theme.textSec)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            }
                         }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Kayıt Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}