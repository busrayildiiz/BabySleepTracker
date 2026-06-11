import Foundation

// MARK: - Daytime Prediction

struct DaytimePrediction {
    let nextNapTime: Date
    let windowStart: Date
    let windowEnd: Date
    let expectedDurationMinutes: Int
    let wakeWindowUsed: Int
    let confidence: Int
    let reasoning: [String]
}

// MARK: - Night Prediction

struct NightPredictionModel {
    let optimalBedtimeStart: Date      // Overtired olmadan yatırılabilecek en erken saat
    let optimalBedtimeEnd: Date         // Bu satten geç yatırılması overtired risk
    let overtiredRiskTime: Date         // Kesinlikle bu satten önce yatırılmalı
    let expectedNightSleepMinutes: Int
    let lastNapCutoffTime: Date         // Bu satten sonra nap önerilmez (gece uyusunu e
    let reasoning: [String]
}

// MARK: - Prediction Agent Protocol

protocol PredictionAgentProtocol {
    func predictNextNap(
        pattern: BabyPattern,
        todayRecords: [SleepRecord],
        wakeTime: Date?,
        ageMonths: Int,
        now: Date
    ) -> DaytimePrediction
    
    func predictBedtime(
        pattern: BabyPattern,
        todayNaps: [SleepRecord],
        ageMonths: Int,
        now: Date
    ) -> NightPredictionModel
}

// MARK: - Prediction Agent Implementation

final class PredictionAgent: NSObject, ObservableObject, PredictionAgentProtocol {
    @Published var nextNapPrediction: DaytimePrediction?
    @Published var bedtimePrediction: NightPredictionModel?
    
    private let calendar = Calendar.current
    
    override init() {
        super.init()
    }
    
    // MARK: - Predict Next Nap
    
    func predictNextNap(
        pattern: BabyPattern,
        todayRecords: [SleepRecord],
        wakeTime: Date?,
        ageMonths: Int,
        now: Date = Date()
    ) -> DaytimePrediction {
        guard let wakeTime = wakeTime else {
            return defaultNapPrediction(now: now)
        }
        
        // AAP temel wake window
        let baselineWindow = getBaselineWakeWindow(ageMonths: ageMonths)
        
        // Pattern'den observed wake window
        let observedWindow = pattern.averageWakeWindowMinutes ?? baselineWindow
        
        // İkisini blend et (pattern kalitesine göre ağırlıklandır)
        let weight = Double(pattern.sampleSize) / 14.0
        let blendedWindow = Int(Double(baselineWindow) * (1 - weight) + Double(observedWindow) * weight)
        
        // Recommended nap time
        let napTime = calendar.date(byAdding: .second, value: blendedWindow * 60, to: wakeTime) ?? now
        
        // Window (±15 dakika)
        let windowStart = calendar.date(byAdding: .minute, value: -15, to: napTime) ?? napTime
        let windowEnd = calendar.date(byAdding: .minute, value: 15, to: napTime) ?? napTime
        
        // Expected duration
        let expectedDuration = pattern.averageNapDurationMinutes ?? 90
        
        // Confidence hesapla
        let confidence = calculateConfidence(
            phase: pattern.dataQuality,
            hasWakeTime: true,
            hasObservedWindow: pattern.averageWakeWindowMinutes != nil
        )
        
        // Reasoning
        var reasoning: [String] = []
        if let wakeWindow = pattern.averageWakeWindowMinutes {
            reasoning.append("Based on \(pattern.sampleSize) days of observed wake windows")
        } else {
            reasoning.append("Based on age-based \(ageMonths)-month guidelines")
        }
        reasoning.append("Expected nap duration: ~\(expectedDuration) minutes")
        reasoning.append("Confidence: \(confidence)%")
        
        let prediction = DaytimePrediction(
            nextNapTime: napTime,
            windowStart: windowStart,
            windowEnd: windowEnd,
            expectedDurationMinutes: expectedDuration,
            wakeWindowUsed: blendedWindow,
            confidence: confidence,
            reasoning: reasoning
        )
        
        nextNapPrediction = prediction
        return prediction
    }
    
    // MARK: - Predict Bedtime
    
    func predictBedtime(
        pattern: BabyPattern,
        todayNaps: [SleepRecord],
        ageMonths: Int,
        now: Date = Date()
    ) -> NightPredictionModel {
        // Yaşa göre ideal bedtime range
        let (bedtimeStart, bedtimeEnd) = getRecommendedBedtimeRange(ageMonths: ageMonths)
        
        // Pattern'den optimal bedtime
        let optimalBedtime: Date
        if let bedtimeRange = pattern.optimalBedtimeRange {
            let midpoint = (bedtimeRange.lowerBound + bedtimeRange.upperBound) / 2
            optimalBedtime = timeToDate(minutesSinceMidnight: midpoint, at: now)
        } else {
            optimalBedtime = timeToDate(minutesSinceMidnight: bedtimeStart, at: now)
        }
        
        // Overtired risk time (30 dakika sonra)
        let overtiredRiskTime = calendar.date(byAdding: .minute, value: 30, to: optimalBedtime) ?? now
        
        // Last nap cutoff (bedtime'dan 2.5 saat önce)
        let lastNapCutoff = calendar.date(byAdding: .minute, value: -150, to: optimalBedtime) ?? now
        
        // Expected night sleep
        let expectedNightSleep = getExpectedNightSleep(ageMonths: ageMonths)
        
        // Reasoning
        var reasoning: [String] = []
        if let bedtimeRange = pattern.optimalBedtimeRange {
            let startHour = bedtimeRange.lowerBound / 60
            let startMin = bedtimeRange.lowerBound % 60
            let endHour = bedtimeRange.upperBound / 60
            let endMin = bedtimeRange.upperBound % 60
            reasoning.append("Observed bedtime range: \(startHour):\(String(format: "%02d", startMin)) - \(endHour):\(String(format: "%02d", endMin))")
        }
        reasoning.append("Expected night sleep: ~\(expectedNightSleep) minutes")
        if let wakeups = pattern.averageNightWakings {
            reasoning.append("Expected night wakings: ~\(Int(wakeups))")
        }
        
        let prediction = NightPredictionModel(
            optimalBedtimeStart: optimalBedtime,
            optimalBedtimeEnd: calendar.date(byAdding: .minute, value: 15, to: optimalBedtime) ?? now,
            overtiredRiskTime: overtiredRiskTime,
            expectedNightSleepMinutes: expectedNightSleep,
            lastNapCutoffTime: lastNapCutoff,
            reasoning: reasoning
        )
        
        bedtimePrediction = prediction
        return prediction
    }
    
    // MARK: - Helper Functions
    
    private func getBaselineWakeWindow(ageMonths: Int) -> Int {
        switch ageMonths {
        case ..<4: return 60        // 1 saat
        case 4...5: return 120      // 2 saat
        case 6...8: return 150      // 2.5 saat
        case 9...11: return 180     // 3 saat
        case 12...14: return 210    // 3.5 saat
        case 15...18: return 240    // 4 saat
        case 19...24: return 300    // 5 saat
        default: return 360         // 6 saat
        }
    }
    
    private func getRecommendedBedtimeRange(ageMonths: Int) -> (start: Int, end: Int) {
        // Dakika cinsinden
        switch ageMonths {
        case ..<4:
            return (1140, 1320)  // 19:00 - 22:00
        case 4...11:
            return (1020, 1140)  // 17:00 - 19:00
        case 12...24:
            return (1020, 1140)  // 17:00 - 19:00
        default:
            return (1080, 1140)  // 18:00 - 19:00
        }
    }
    
    private func getExpectedNightSleep(ageMonths: Int) -> Int {
        switch ageMonths {
        case ..<4: return 0
        case 4...11: return 9 * 60      // 9 saat
        case 12...35: return 10 * 60    // 10 saat
        default: return 10 * 60         // 10 saat
        }
    }
    
    private func calculateConfidence(
        phase: DataQuality,
        hasWakeTime: Bool,
        hasObservedWindow: Bool
    ) -> Int {
        var confidence = 54
        
        switch phase {
        case .excellent:
            confidence += 30
        case .good:
            confidence += 20
        case .fair:
            confidence += 10
        case .poor:
            confidence += 0
        }
        
        if hasWakeTime { confidence += 8 }
        if hasObservedWindow { confidence += 5 }
        
        return min(94, confidence)
    }
    
    private func timeToDate(minutesSinceMidnight: Int, at date: Date) -> Date {
        let hours = minutesSinceMidnight / 60
        let minutes = minutesSinceMidnight % 60
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        var newComponents = components
        newComponents.hour = hours
        newComponents.minute = minutes
        return calendar.date(from: newComponents) ?? date
    }
}
