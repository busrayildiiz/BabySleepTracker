//
//  PhaseAgentProtocol.swift
//  BabySleepTracker
//
//  Created by MacBook on 12.06.2026.
//

import Foundation

protocol PhaseAgentProtocol {
    func currentPhase(ageMonths: Int, trackedDays: Int) -> CoachPhase
    func readinessReport(
        ageMonths: Int,
        trackedDays: Int,
        hasTodayWakeTime: Bool,
        hasYesterdayNightSleep: Bool
    ) -> PhaseReadinessReport
}
