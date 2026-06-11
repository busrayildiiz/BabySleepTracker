import Foundation

// MARK: - Trend & Data Quality

enum Trend {
    case increasing   // Artiyor
    case stable       // Sabit
    case decreasing   // Azalıyor
    case insufficient // Yeterli veri yok
}

enum DataQuality {
    case poor
    case fair
    case good
    case excellent
}

// MARK: - BabyPattern Model

struct BabyPattern {
    // Gündüz
    let averageWakeWindowMinutes: Int?      // Uyanış ile uyumak arası
    let bestFirstNapHour: Int?              // Gün içi ilk nap'ı için ideal saat
    let averageNapDurationMinutes: Int?     // Ortalama gündüz nap süresi
    let napCountPerDay: Double?             // Ortalama günlük nap sayısı
    
    // Gece
    let optimalBedtimeRange: ClosedRange<Int>?  // Dakika cinsinden (örn. 1140...1200 = 19:00...20:00)
    let averageNightSleepMinutes: Int?          // Gece uyku süresi
    let averageNightWakings: Double?            // Gece uyanış sayısı
    
    // Trendler
    let wakingWindowTrend: Trend    // Artıyor mu, azalıyor mu?
    let napDurationTrend: Trend     // Nap süresi artıyor mu?
    
    // Güvenilirlik
    let sampleSize: Int             // Kaç gün veri toplandı?
    let dataQuality: DataQuality    // .poor / .fair / .good / .excellent
}

// MARK: - PatternAgent Protocol

protocol PatternAgentProtocol {
    func analyze(
        records: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        ageMonths: Int
    ) -> BabyPattern
}

// MARK: - PatternAgent Implementation

final class PatternAgent: NSObject, ObservableObject, PatternAgentProtocol {
    @Published var currentPattern: BabyPattern?
    
    private let memoryStore = SleepMemoryStore.shared
    private let calendar = Calendar.current
    
    override init() {
        super.init()
    }
    
    // MARK: - Main Analysis
    
    func analyze(
        records: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        ageMonths: Int
    ) -> BabyPattern {
        let breaks = records.filter { $0.kind == .break }
        let sleeps = records.filter { $0.kind != .break }
        let dayNaps = sleeps.filter { $0.kind == .dayNap }
        let nightSleeps = sleeps.filter { $0.kind == .nightSleep }
        
        let sortedNaps = dayNaps.sorted { $0.date < $1.date }
        let sortedNights = nightSleeps.sorted { $0.date < $1.date }
        
        // Veri kalitesi ve sample size
        let uniqueDays = Set(records.map { calendar.startOfDay(for: $0.date) }).count
        let sampleSize = uniqueDays
        let dataQuality = determineDataQuality(sampleSize: sampleSize)
        
        // Gündüz analizi
        let (wakeWindow, bestHour, napDuration, napCount) = analyzeDayNaps(
            dayNaps: sortedNaps,
            wakeRecords: wakeRecords,
            breaks: breaks
        )
        
        // Gece analizi
        let (bedtimeRange, nightDuration, nightWakings) = analyzeNightSleep(
            nightSleeps: sortedNights,
            breaks: breaks
        )
        
        // Trendler
        let wakingTrend = calculateTrend(dayNaps: sortedNaps, wakeRecords: wakeRecords)
        let napTrend = calculateNapTrend(dayNaps: sortedNaps, breaks: breaks)
        
        let pattern = BabyPattern(
            averageWakeWindowMinutes: wakeWindow,
            bestFirstNapHour: bestHour,
            averageNapDurationMinutes: napDuration,
            napCountPerDay: napCount,
            optimalBedtimeRange: bedtimeRange,
            averageNightSleepMinutes: nightDuration,
            averageNightWakings: nightWakings,
            wakingWindowTrend: wakingTrend,
            napDurationTrend: napTrend,
            sampleSize: sampleSize,
            dataQuality: dataQuality
        )
        
        currentPattern = pattern
        return pattern
    }
    
    // MARK: - Day Naps Analysis
    
    private func analyzeDayNaps(
        dayNaps: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        breaks: [SleepRecord]
    ) -> (wakeWindow: Int?, bestHour: Int?, napDuration: Int?, napCount: Double?) {
        guard !dayNaps.isEmpty else {
            return (nil, nil, nil, nil)
        }
        
        // 1. Wake window (Uyanış ile uyumak arası)
        var wakeWindows: [Int] = []
        for nap in dayNaps {
            let dayStart = calendar.startOfDay(for: nap.date)
            
            let previousNap = dayNaps.last {
                $0.date < nap.date && calendar.isDate($0.date, inSameDayAs: nap.date)
            }
            
            let anchor: Date?
            if let previousNap {
                anchor = calendar.date(byAdding: .second, value: previousNap.duration, to: previousNap.date)
            } else {
                anchor = wakeRecords.last {
                    calendar.isDate($0.day, inSameDayAs: dayStart) && $0.wakeTime <= nap.date
                }?.wakeTime
            }
            
            if let anchor {
                let minutes = Int(nap.date.timeIntervalSince(anchor) / 60)
                if (30...600).contains(minutes) {
                    wakeWindows.append(minutes)
                }
            }
        }
        
        let avgWakeWindow = wakeWindows.isEmpty ? nil : median(wakeWindows)
        
        // 2. Best first nap hour
        let groupedByHour = Dictionary(grouping: dayNaps) { calendar.component(.hour, from: $0.date) }
        let hourAverages = groupedByHour.mapValues { naps in
            naps.map { $0.totalMinutes(breaks: breaks) }.reduce(0, +) / max(naps.count, 1)
        }
        let bestHour = hourAverages.max { $0.value < $1.value }?.key
        
        // 3. Average nap duration
        let napDurations = dayNaps.map { $0.totalMinutes(breaks: breaks) }.filter { $0 > 0 }
        let avgNapDuration = napDurations.isEmpty ? nil : napDurations.reduce(0, +) / napDurations.count
        
        // 4. Nap count per day
        let uniqueDays = Set(dayNaps.map { calendar.startOfDay(for: $0.date) }).count
        let napCountPerDay = uniqueDays > 0 ? Double(dayNaps.count) / Double(uniqueDays) : nil
        
        return (avgWakeWindow, bestHour, avgNapDuration, napCountPerDay)
    }
    
    // MARK: - Night Sleep Analysis
    
    private func analyzeNightSleep(
        nightSleeps: [SleepRecord],
        breaks: [SleepRecord]
    ) -> (bedtimeRange: ClosedRange<Int>?, nightDuration: Int?, nightWakings: Double?) {
        guard !nightSleeps.isEmpty else {
            return (nil, nil, nil)
        }
        
        // 1. Bedtime range (Dakika cinsinden)
        var bedtimes: [Int] = []
        for night in nightSleeps {
            let hour = calendar.component(.hour, from: night.date)
            let minute = calendar.component(.minute, from: night.date)
            let totalMinutes = hour * 60 + minute
            bedtimes.append(totalMinutes)
        }
        
        let bedtimeRange: ClosedRange<Int>?
        if !bedtimes.isEmpty {
            let sortedBedtimes = bedtimes.sorted()
            let min = sortedBedtimes.first ?? 0
            let max = sortedBedtimes.last ?? 0
            bedtimeRange = min...max
        } else {
            bedtimeRange = nil
        }
        
        // 2. Average night sleep duration
        let durations = nightSleeps.map { $0.totalMinutes(breaks: breaks) }.filter { $0 > 0 }
        let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / durations.count
        
        // 3. Average night wakings
        let avgWakings = nightSleeps.isEmpty ? nil : Double(nightSleeps.count)
        
        return (bedtimeRange, avgDuration, avgWakings)
    }
    
    // MARK: - Trend Calculation
    
    private func calculateTrend(
        dayNaps: [SleepRecord],
        wakeRecords: [DailyWakeRecord]
    ) -> Trend {
        guard dayNaps.count >= 7 else { return .insufficient }
        
        let sortedNaps = dayNaps.sorted { $0.date < $1.date }
        let recentNaps = Array(sortedNaps.suffix(7))
        let olderNaps = Array(sortedNaps.dropLast(7).suffix(7))
        
        guard !recentNaps.isEmpty, !olderNaps.isEmpty else { return .insufficient }
        
        var recentWindows: [Int] = []
        var olderWindows: [Int] = []
        
        // Recent wake windows
        for nap in recentNaps {
            if let wake = wakeRecords.last(where: {
                calendar.isDate($0.day, inSameDayAs: nap.date) && $0.wakeTime <= nap.date
            }) {
                let minutes = Int(nap.date.timeIntervalSince(wake.wakeTime) / 60)
                if (30...600).contains(minutes) {
                    recentWindows.append(minutes)
                }
            }
        }
        
        // Older wake windows
        for nap in olderNaps {
            if let wake = wakeRecords.last(where: {
                calendar.isDate($0.day, inSameDayAs: nap.date) && $0.wakeTime <= nap.date
            }) {
                let minutes = Int(nap.date.timeIntervalSince(wake.wakeTime) / 60)
                if (30...600).contains(minutes) {
                    olderWindows.append(minutes)
                }
            }
        }
        
        guard let recentAvg = average(recentWindows),
              let olderAvg = average(olderWindows) else { return .insufficient }
        
        let diff = recentAvg - olderAvg
        if diff > 15 {
            return .increasing
        } else if diff < -15 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateNapTrend(
        dayNaps: [SleepRecord],
        breaks: [SleepRecord]
    ) -> Trend {
        guard dayNaps.count >= 7 else { return .insufficient }
        
        let sortedNaps = dayNaps.sorted { $0.date < $1.date }
        let recentNaps = Array(sortedNaps.suffix(7))
        let olderNaps = Array(sortedNaps.dropLast(7).suffix(7))
        
        guard !recentNaps.isEmpty, !olderNaps.isEmpty else { return .insufficient }
        
        let recentDurations = recentNaps.map { $0.totalMinutes(breaks: breaks) }
        let olderDurations = olderNaps.map { $0.totalMinutes(breaks: breaks) }
        
        guard let recentAvg = average(recentDurations),
              let olderAvg = average(olderDurations) else { return .insufficient }
        
        let diff = recentAvg - olderAvg
        if diff > 10 {
            return .increasing
        } else if diff < -10 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    // MARK: - Data Quality
    
    private func determineDataQuality(sampleSize: Int) -> DataQuality {
        switch sampleSize {
        case 0...2:
            return .poor
        case 3...6:
            return .fair
        case 7...13:
            return .good
        default:
            return .excellent
        }
    }
    
    // MARK: - Utility Functions
    
    private func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
    
    private func average(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }
}
