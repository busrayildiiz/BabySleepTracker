//
//  PredictAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.
//

import Foundation

struct DaytimePrediction {
    let nextNapTime: Date
    let windowStart: Date
    let windowEnd: Date
    let expectedDurationMinutes: Int
    let wakeWindowUsed: Int
    let confidence: Int
    let reasoning: [String]
}

struct NightPrediction {
    let optimalBedtimeStart: Date   // Overtired olmadan yatırılabilecek en erken saat
    let optimalBedtimeEnd: Date     // Bu saatten geç kalırsa overtired riski
    let overtiredRiskTime: Date     // Kesinlikle bu saatten önce yatırılmalı
    let expectedNightSleepMinutes: Int
    let lastNapCutoffTime: Date     // Bu saatten sonra nap önerilmez (gece uykusunu etkiler)
    let reasoning: [String]
}

protocol PredictionAgentProtocol {
    func predictNextNap(pattern: BabyPattern,
                        todayRecords: [SleepRecord],
                        wakeTime: Date?,
                        ageMonths: Int,
                        now: Date) -> DaytimePrediction
    
    func predictBedtime(pattern: BabyPattern,
                        todayNaps: [SleepRecord],
                        ageMonths: Int,
                        now: Date) -> NightPrediction
}
