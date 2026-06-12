//
//  WakeWindowBaselineAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.
//

import Foundation
struct WakeWindowBaselineAgent: WakeWindowBaselineProviding {
    func wakeWindow(forAgeMonths ageMonths: Int) -> ClosedRange<Int> {
        switch ageMonths {
        case ..<4: return 60...120
        case 4...5: return 90...150
        case 6...8: return 120...180
        case 9...11: return 150...210
        case 12...14: return 180...240
        case 15...18: return 240...300
        case 19...24: return 300...360
        default: return 300...390
        }
    }
}
