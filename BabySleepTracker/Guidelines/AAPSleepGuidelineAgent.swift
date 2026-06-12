//
//  AAPSleepGuidelineAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.
//

import Foundation
struct AAPSleepGuidelineAgent: PediatricSleepGuidelineProviding {
    func guideline(forAgeMonths ageMonths: Int) -> SleepGuideline {
        let range: ClosedRange<Int>
        switch ageMonths {
        case ..<4:
            range = 0...0
        case 4...11:
            range = 12 * 60...16 * 60
        case 12...35:
            range = 11 * 60...14 * 60
        default:
            range = 10 * 60...13 * 60
        }

        return SleepGuideline(
            minimumDailyMinutes: range.lowerBound,
            maximumDailyMinutes: range.upperBound,
            sourceName: "AAP-endorsed AASM sleep duration guidance",
            sourceURL: "https://aasm.org/recharge-with-sleep-pediatric-sleep-recommendations-promoting-optimal-health/"
        )
    }
}
