//
//  PhaseAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.
//

import Foundation

enum CoachPhase {
    case tooYoung          // 0-4 ay: sadece bilgilendirme
    case baseline          // 4ay+ ilk gün: yaşa göre genel
    case learning(day: Int) // 1-13. gün: veri toplama
    case personalized      // 14+ gün: tam kişiselleştirme
}

protocol PhaseAgentProtocol {
    func currentPhase(ageMonths: Int, trackedDays: Int) -> CoachPhase
    func readinessReport() -> PhaseReadinessReport
}

struct PhaseReadinessReport {
    let phase: CoachPhase
    let daysUntilPersonalized: Int
    let missingSignals: [MissingSignal]  // "wake time eksik", "gece uykusu yok" gibi
    let confidence: Int
}

enum MissingSignal: String {
    case wakeTime = "Add today's wake-up time"
    case nightSleep = "Log last night's sleep"
    case consecutiveDays = "Track more consecutive days"
}
