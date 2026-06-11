import Foundation

// MARK: - OvertiredCalculator

final class OvertiredCalculator: NSObject, ObservableObject {
    @Published var overtiredLevel: Double = 0
    @Published var overtireRisk: OvertireRisk = .healthy
    
    private let memoryStore = SleepMemoryStore.shared
    private let calendar = Calendar.current
    
    override init() {
        super.init()
    }
    
    // MARK: - Overtire Risk Levels
    
    enum OvertireRisk: String {
        case healthy          // 0-20%
        case slightlyTired     // 20-40%
        case moderate          // 40-60%
        case significant       // 60-80%
        case criticallyTired   // 80%+
        
        var color: String {
            switch self {
            case .healthy: return "green"
            case .slightlyTired: return "yellow"
            case .moderate: return "orange"
            case .significant: return "red"
            case .criticallyTired: return "darkred"
            }
        }
        
        var advice: String {
            switch self {
            case .healthy:
                return "Great! Your baby is well-rested."
            case .slightlyTired:
                return "Your baby is getting slightly tired. Watch for sleepy cues."
            case .moderate:
                return "Your baby is moderately tired. Consider an earlier nap time."
            case .significant:
                return "Your baby is significantly overtired. Prioritize sleep soon."
            case .criticallyTired:
                return "Your baby is critically overtired. Immediate nap needed to reset."
            }
        }
    }
    
    // MARK: - Calculate Overtired Level
    
    func calculateOvertiredLevel(
        sleepRecords: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        ageMonths: Int,
        now: Date = Date()
    ) -> Double {
        let breaks = sleepRecords.filter { $0.kind == .break }
        let sleeps = sleepRecords.filter { $0.kind != .break }
        let dayNaps = sleeps.filter { $0.kind == .dayNap }
        let nightSleeps = sleeps.filter { $0.kind == .nightSleep }
        
        // Yaşa göre ideal uyku süresi (AAP rehberleri)
        let idealDailyMinutes = getIdealDailyMinutes(ageMonths: ageMonths)
        
        // Son 7 günün toplam uyku süresi
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recentSleeps = sleeps.filter { $0.date >= sevenDaysAgo }
        let recentTotalMinutes = recentSleeps.map { $0.totalMinutes(breaks: breaks) }.reduce(0, +)
        let recentAverage = recentSleeps.isEmpty ? 0 : recentTotalMinutes / (7 * 60) // saat cinsinden
        
        // Bugün kaç saat uyudu?
        let todaySleeps = sleeps.filter { calendar.isDateInToday($0.date) }
        let todayTotalMinutes = todaySleeps.map { $0.totalMinutes(breaks: breaks) }.reduce(0, +)
        let todayHours = Double(todayTotalMinutes) / 60.0
        
        // Bugün kaç saat geçti ve en son ne zaman uyudu?
        let hoursSinceWake = calculateHoursSinceWake(wakeRecords: wakeRecords, now: now)
        let hoursSinceSleep = calculateHoursSinceSleep(sleeps: sleeps, now: now)
        
        // 1. Sleep debt (uyku borcu)
        let idealDaily = Double(idealDailyMinutes) / 60.0
        let sleepDebtFactor = max(0, idealDaily - recentAverage) / idealDaily
        
        // 2. Time awake factor (uyanık kalma süresi)
        let maxWakeWindow = getMaxWakeWindow(ageMonths: ageMonths)
        let wakeTimeFactor = max(0, Double(hoursSinceWake) - Double(maxWakeWindow)) / Double(maxWakeWindow)
        
        // 3. Recent nap pattern (son nap'lar arası)
        let timeSinceLastNap = hoursSinceSleep
        let napsToday = todaySleeps.count
        let napIntervalFactor = napsToday > 0 ? min(1.0, timeSinceLastNap / 3.0) : 0.5 // 3 saat sonra 100%
        
        // Combined overtired level
        let level = (sleepDebtFactor * 0.3) + (wakeTimeFactor * 0.4) + (napIntervalFactor * 0.3)
        let clampedLevel = min(1.0, max(0, level))
        
        overtiredLevel = clampedLevel
        overtireRisk = determineOvertireRisk(level: clampedLevel)
        memoryStore.setOvertiredLevel(clampedLevel)
        
        return clampedLevel
    }
    
    // MARK: - Predict Next Night
    
    func predictNextNight(
        sleepRecords: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        overtiredLevel: Double,
        ageMonths: Int,
        now: Date = Date()
    ) -> NightPrediction {
        let breaks = sleepRecords.filter { $0.kind == .break }
        let nightSleeps = sleepRecords.filter { $0.kind == .nightSleep }
        
        // Son 7 gecenin ortalama süresi
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recentNights = nightSleeps.filter { $0.date >= sevenDaysAgo }
        
        let avgNightDuration: Double
        if recentNights.isEmpty {
            // Yaşa göre tavsiye edilen
            avgNightDuration = Double(getIdealNightMinutes(ageMonths: ageMonths))
        } else {
            let durations = recentNights.map { Double($0.totalMinutes(breaks: breaks)) }
            avgNightDuration = durations.reduce(0, +) / Double(durations.count)
        }
        
        // Overtired seviyesine göre uyku süresini ayarla
        // Yorgun bebek daha uzun uyur (0-30% artış)
        let adjustedDuration = avgNightDuration * (1.0 + overtiredLevel * 0.3)
        
        // Yaşa göre tavsiye edilen bedtime range
        let (bedtimeStart, bedtimeEnd) = getRecommendedBedtimeRange(ageMonths: ageMonths)
        
        // Overtired ise daha erken yatırırız
        let bedtimeAdjustment = Int(overtiredLevel * 30) // max 30 dakika erkene
        let recommendedBedtime = bedtimeStart - bedtimeAdjustment
        
        // Zamanları hesapla
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        dateComponents.hour = recommendedBedtime / 60
        dateComponents.minute = recommendedBedtime % 60
        let bedtime = calendar.date(from: dateComponents) ?? now
        
        let wakeup = calendar.date(byAdding: .second, value: Int(adjustedDuration * 60), to: bedtime) ?? now
        
        // Confidence: overtired ise daha yüksek (belirli), yoksa daha düşük
        let confidence = 0.65 + (overtiredLevel * 0.25)
        
        let prediction = NightPrediction(
            predictedBedtime: bedtime,
            expectedDuration: adjustedDuration * 60, // saniye
            confidence: confidence,
            recommendedWakeup: wakeup
        )
        
        memoryStore.saveNightPrediction(prediction)
        return prediction
    }
    
    // MARK: - Helper Functions
    
    private func getIdealDailyMinutes(ageMonths: Int) -> Int {
        switch ageMonths {
        case ..<4: return 0      // Tavsiye yok
        case 4...11: return 12 * 60 + 48 * 60   // 12-16 saat (orta: 14 saat)
        case 12...35: return 11 * 60 + 56 * 60  // 11-14 saat (orta: 13 saat)
        default: return 10 * 60 + 39 * 60       // 10-13 saat (orta: 11.5 saat)
        }
    }
    
    private func getIdealNightMinutes(ageMonths: Int) -> Int {
        switch ageMonths {
        case ..<4: return 0
        case 4...11: return 9 * 60      // 8-10 saat, ortalama 9
        case 12...35: return 10 * 60    // 9-11 saat, ortalama 10
        default: return 10 * 60         // 10 saat
        }
    }
    
    private func getMaxWakeWindow(ageMonths: Int) -> Int {
        switch ageMonths {
        case ..<4: return 1          // 1 saat
        case 4...5: return 2         // 2 saat
        case 6...8: return 3         // 3 saat
        case 9...11: return 3.5      // 3.5 saat
        case 12...14: return 4       // 4 saat
        case 15...18: return 5       // 5 saat
        case 19...24: return 6       // 6 saat
        default: return 7            // 7+ saat
        }
    }
    
    private func getRecommendedBedtimeRange(ageMonths: Int) -> (start: Int, end: Int) {
        // Dakika cinsinden (örn: 1140 = 19:00)
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
    
    private func calculateHoursSinceWake(wakeRecords: [DailyWakeRecord], now: Date) -> Int {
        let today = calendar.startOfDay(for: now)
        if let todayWake = wakeRecords.last(where: { calendar.isDate($0.day, inSameDayAs: now) }) {
            return Int(now.timeIntervalSince(todayWake.wakeTime) / 3600)
        }
        return 0
    }
    
    private func calculateHoursSinceSleep(sleeps: [SleepRecord], now: Date) -> Int {
        if let lastSleep = sleeps.last {
            let napEnd = calendar.date(byAdding: .second, value: lastSleep.duration, to: lastSleep.date) ?? lastSleep.date
            return Int(now.timeIntervalSince(napEnd) / 3600)
        }
        return 0
    }
    
    private func determineOvertireRisk(level: Double) -> OvertireRisk {
        switch level {
        case 0..<0.2:
            return .healthy
        case 0.2..<0.4:
            return .slightlyTired
        case 0.4..<0.6:
            return .moderate
        case 0.6..<0.8:
            return .significant
        default:
            return .criticallyTired
        }
    }
}
