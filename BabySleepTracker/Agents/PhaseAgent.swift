//
//  PhaseAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 12.06.2026.
//

import Foundation

// MARK: - CoachPhase

enum CoachPhase: Equatable {
    case tooYoung              // 0–4 ay: sadece güvenli uyku bilgisi
    case baseline              // 4 ay+, 0 tracked day: yaşa göre genel tablolar
    case learning(day: Int)    // 1–13. gün: veri toplama, blending başlar
    case personalized          // 14+ gün: tam kişiselleştirme
}

// MARK: - MissingSignal

enum MissingSignal: String, CaseIterable {
    case wakeTime        = "Bugünün uyanma saatini ekle"
    case nightSleep      = "Dün gecenin uykusunu logla"
    case consecutiveDays = "Daha fazla ardışık gün takip et"
}

// MARK: - PhaseReadinessReport

struct PhaseReadinessReport {
    let phase: CoachPhase
    let daysUntilPersonalized: Int   // 0 ise zaten personalized
    let missingSignals: [MissingSignal]
    let confidence: Int              // 0–100
    let progressLabel: String        // UI'da gösterilecek kısa açıklama
}


// MARK: - DefaultPhaseAgent

final class DefaultPhaseAgent: PhaseAgentProtocol {

    // MARK: - currentPhase

    func currentPhase(ageMonths: Int, trackedDays: Int) -> CoachPhase {
        // 4 aydan küçükse hiçbir pattern beklenmez
        guard ageMonths >= 4 else {
            return .tooYoung
        }

        switch trackedDays {
        case 0:
            return .baseline
        case 1...13:
            return .learning(day: trackedDays)
        default:
            return .personalized
        }
    }

    // MARK: - readinessReport

    func readinessReport(
        ageMonths: Int,
        trackedDays: Int,
        hasTodayWakeTime: Bool,
        hasYesterdayNightSleep: Bool
    ) -> PhaseReadinessReport {

        let phase = currentPhase(ageMonths: ageMonths, trackedDays: trackedDays)

        let daysUntilPersonalized: Int = {
            switch phase {
            case .tooYoung:              return -1   // geçerli değil
            case .baseline:              return 14
            case .learning(let day):     return 14 - day
            case .personalized:          return 0
            }
        }()

        // Eksik sinyaller
        var missing: [MissingSignal] = []
        if !hasTodayWakeTime        { missing.append(.wakeTime) }
        if !hasYesterdayNightSleep  { missing.append(.nightSleep) }
        if trackedDays < 3          { missing.append(.consecutiveDays) }

        // Confidence hesabı
        let confidence = calculateConfidence(
            phase: phase,
            trackedDays: trackedDays,
            hasTodayWakeTime: hasTodayWakeTime,
            hasYesterdayNightSleep: hasYesterdayNightSleep
        )

        // Progress label
        let progressLabel = makeProgressLabel(
            phase: phase,
            trackedDays: trackedDays,
            daysUntilPersonalized: daysUntilPersonalized
        )

        return PhaseReadinessReport(
            phase: phase,
            daysUntilPersonalized: daysUntilPersonalized,
            missingSignals: missing,
            confidence: confidence,
            progressLabel: progressLabel
        )
    }

    // MARK: - Private Helpers

    private func calculateConfidence(
        phase: CoachPhase,
        trackedDays: Int,
        hasTodayWakeTime: Bool,
        hasYesterdayNightSleep: Bool
    ) -> Int {
        var score = 0

        switch phase {
        case .tooYoung:
            return 0
        case .baseline:
            score = 40
        case .learning(let day):
            // Her gün +3 puan, max 14 günde +42
            score = 40 + (day * 3)
        case .personalized:
            score = 82
        }

        // Bonus sinyaller
        if hasTodayWakeTime       { score += 8 }
        if hasYesterdayNightSleep { score += 5 }

        return min(score, 94)  // max 94 — hiçbir zaman %100 değil
    }

    private func makeProgressLabel(
        phase: CoachPhase,
        trackedDays: Int,
        daysUntilPersonalized: Int
    ) -> String {
        switch phase {
        case .tooYoung:
            return "4 aylıktan itibaren aktif olur"
        case .baseline:
            return "İlk uykuyu logla — öğrenme başlasın"
        case .learning(let day):
            let remaining = 14 - day
            return "\(day)/14 gün • \(remaining) gün sonra kişiselleşiyor"
        case .personalized:
            return "Kişiselleştirilmiş mod aktif ✓"
        }
    }
}
