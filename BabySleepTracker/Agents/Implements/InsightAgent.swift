//
//  InsightAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.

import Foundation

// MARK: - Alert Types

enum AlertSeverity { case info, warning, critical }
enum AlertAction   { case addWakeTime, addNap, addNightSleep }

struct SleepAlert {
    let severity:    AlertSeverity
    let message:     String
    let actionTitle: String?
    let actionType:  AlertAction?
}

// MARK: - Insight Bundle

struct SleepInsightBundle {
    let headline:        String
    let coachTip:        String
    let alerts:          [SleepAlert]
    let weeklyPattern:   String?
    let progressMessage: String
}

// MARK: - Protocol

protocol InsightAgentProtocol {
    func buildInsights(
        phase:         CoachPhase,
        pattern:       BabyPattern?,
        trackedDays:   Int,
        babyName:      String
    ) -> SleepInsightBundle
}

// MARK: - DefaultInsightAgent

final class DefaultInsightAgent: InsightAgentProtocol {

    func buildInsights(
        phase:       CoachPhase,
        pattern:     BabyPattern?,
        trackedDays: Int,
        babyName:    String
    ) -> SleepInsightBundle {

        SleepInsightBundle(
            headline:        headline(phase: phase),
            coachTip:        coachTip(phase: phase, pattern: pattern, babyName: babyName),
            alerts:          alerts(phase: phase, pattern: pattern),
            weeklyPattern:   weeklyPattern(pattern: pattern, babyName: babyName),
            progressMessage: progressMessage(phase: phase, trackedDays: trackedDays, babyName: babyName)
        )
    }

    // MARK: - Headline

    private func headline(phase: CoachPhase) -> String {
        switch phase {
        case .tooYoung:          return "4 aylıktan itibaren aktif olur"
        case .baseline:          return "Öğrenme başlasın!"
        case .learning(let day): return "\(day)/14 — örüntü oluşuyor"
        case .personalized:      return "Kişiselleştirilmiş mod aktif ✓"
        }
    }

    // MARK: - Coach Tip

    private func coachTip(
        phase:    CoachPhase,
        pattern:  BabyPattern?,
        babyName: String
    ) -> String {
        switch phase {
        case .tooYoung:
            return "\(babyName) henüz 4 aylıktan küçük. Bu dönemde doğal ritmine göre beslen ve uyu."

        case .baseline:
            return "İlk uykuyu logla. Uyanma saatini de ekleyerek tahminleri güçlendir."

        case .learning(let day):
            let remaining = 14 - day
            return "Harika gidiyorsun! \(remaining) gün daha takip edince kişiselleştirilmiş tahminler başlıyor."

        case .personalized:
            if let hour = pattern?.bestFirstNapHour,
               let extra = pattern?.bestNapExtraMinutes,
               extra > 5 {
                return "\(babyName)'in en uzun napları saat \(formatHour(hour)) civarında başlıyor — ortalamadan ~\(extra) dk daha uzun."
            }
            return "Tahminler \(babyName)'in kendi ritmine göre üretiliyor. Her kayıt sistemi daha da güçlendiriyor."
        }
    }

    // MARK: - Alerts

    private func alerts(phase: CoachPhase, pattern: BabyPattern?) -> [SleepAlert] {
        var result: [SleepAlert] = []

        // Veri kalitesi uyarısı
        if let pattern = pattern, pattern.dataQuality == .poor {
            result.append(SleepAlert(
                severity:    .info,
                message:     "Daha fazla gün takip et — tahminler güçlenecek.",
                actionTitle: nil,
                actionType:  nil
            ))
        }

        // Wake time eksik uyarısı
        switch phase {
        case .baseline, .learning:
            result.append(SleepAlert(
                severity:    .warning,
                message:     "Bugünün uyanma saatini ekle — tahmin doğruluğu artar.",
                actionTitle: "Ekle",
                actionType:  .addWakeTime
            ))
        default:
            break
        }

        return result
    }

    // MARK: - Weekly Pattern

    private func weeklyPattern(pattern: BabyPattern?, babyName: String) -> String? {
        guard let pattern, pattern.sampleSize >= 7 else { return nil }

        var parts: [String] = []

        if let hour = pattern.bestFirstNapHour {
            parts.append("En iyi nap saati: \(formatHour(hour))")
        }

        switch pattern.wakingWindowTrend {
        case .increasing: parts.append("Uyanıklık penceresi uzuyor")
        case .decreasing: parts.append("Uyanıklık penceresi kısalıyor")
        case .stable:     parts.append("Uyanıklık penceresi tutarlı")
        case .insufficient: break
        }

        switch pattern.napDurationTrend {
        case .increasing: parts.append("Naplar uzuyor")
        case .decreasing: parts.append("Naplar kısalıyor")
        case .stable:     parts.append("Nap süresi tutarlı")
        case .insufficient: break
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    // MARK: - Progress Message

    private func progressMessage(
        phase:       CoachPhase,
        trackedDays: Int,
        babyName:    String
    ) -> String {
        switch phase {
        case .tooYoung:
            return "\(babyName) 4 aylık olduğunda tahminler başlayacak."
        case .baseline:
            return "Henüz veri yok. \(babyName)'in ilk uykusunu logla."
        case .learning(let day):
            return "\(day) gün takip edildi. \(14 - day) gün kaldı."
        case .personalized:
            return "Kişiselleştirilmiş! \(trackedDays) gün verisi kullanılıyor."
        }
    }

    // MARK: - Helper

    private func formatHour(_ hour: Int) -> String {
        let suffix      = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour) \(suffix)"
    }
}
