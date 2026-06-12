//
//  PatternAgentProtocol.swift
//  BabySleepTracker
//
//  Created by MacBook on 12.06.2026.
//

import Foundation

protocol PatternAgentProtocol {
    func analyze(
        records: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        ageMonths: Int,
        now: Date
    ) -> BabyPattern
}
