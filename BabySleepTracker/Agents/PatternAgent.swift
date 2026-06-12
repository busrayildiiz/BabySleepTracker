//
//  PatternAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.
//

import Foundation

struct BabyPattern {
    // Gündüz
    let averageWakeWindowMinutes: Int?
    let bestFirstNapHour: Int?           // Günün ilk napı için ideal saat
    let averageNapDurationMinutes: Int?
    let napCountPerDay: Double?          // Ortalama günlük nap sayısı
    
    // Gece
    let optimalBedtimeRange: ClosedRange<Int>?  // Dakika cinsinden (ör. 1140...1200 = 19:00-20:00)
    let averageNightSleepMinutes: Int?
    let averageNightWakings: Double?
    
    // Trendler
    let wakingWindowTrend: Trend         // Artıyor mu, azalıyor mu?
    let napDurationTrend: Trend
    
    // Güvenilirlik
    let sampleSize: Int
    let dataQuality: DataQuality         // .poor / .fair / .good / .excellent
}

enum Trend { case increasing, stable, decreasing, insufficient }
enum DataQuality { case poor, fair, good, excellent }

protocol PatternAgentProtocol {
    func analyze(records: [SleepRecord],
                 wakeRecords: [DailyWakeRecord],
                 ageMonths: Int) -> BabyPattern
}
