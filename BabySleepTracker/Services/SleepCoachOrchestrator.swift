import Foundation
import Combine

/// Merkezi orkestratör - tüm agentleri koordine eder ve Views'a data sağlar
final class SleepCoachOrchestrator: NSObject, ObservableObject {
    static let shared = SleepCoachOrchestrator()
    
    // MARK: - Published Properties (UI binding için)
    
    @Published var currentPhase: CoachPhase = .baseline
    @Published var phaseReport: PhaseReadinessReport?
    @Published var babyPattern: BabyPattern?
    @Published var napPrediction: DaytimePrediction?
    @Published var bedtimePrediction: NightPredictionModel?
    @Published var overtiredLevel: Double = 0
    @Published var overtireRisk: OvertiredCalculator.OvertireRisk = .healthy
    @Published var insights: SleepInsightBundle?
    @Published var lastUpdateTime: Date?
    
    // MARK: - Private Components (Agents)
    
    private let memoryStore = SleepMemoryStore.shared
    private let phaseAgent = PhaseAgent()
    private let patternAgent = PatternAgent()
    private let predictionAgent = PredictionAgent()
    private let overtiredCalculator = OvertiredCalculator()
    private let insightAgent = InsightAgent()
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Notification center'dan updates dinle
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("sleepRecordsDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAllMetrics()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("dailyWakeRecordsDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAllMetrics()
        }
    }
    
    // MARK: - Main Update Method
    
    func updateAllMetrics(now: Date = Date()) {
        let sleepRecords = memoryStore.loadSleepRecords()
        let wakeRecords = memoryStore.loadDailyWakeRecords()
        let babyBirthDate = memoryStore.getBabyBirthDate()
        
        // Yaş hesapla
        let ageMonths = calculateAgeMonths(birthDate: babyBirthDate, at: now)
        
        // Helper calculations
        let breaks = sleepRecords.filter { $0.kind == .break }
        let sleeps = sleepRecords.filter { $0.kind != .break }
        let dayNaps = sleeps.filter { $0.kind == .dayNap }
        let trackedDays = calculateTrackedDays(sleeps: sleeps, wakeRecords: wakeRecords)
        let hasTodayWakeTime = hasTodayWakeTime(wakeRecords: wakeRecords, now: now)
        let hasNightSleep = hasRecentNightSleep(sleepRecords: sleeps)
        let todayWakeTime = getTodayWakeTime(wakeRecords: wakeRecords, now: now)
        let todayNaps = dayNaps.filter { calendar.isDateInToday($0.date) }
        
        // 1. Phase Report
        phaseReport = phaseAgent.readinessReport(
            ageMonths: ageMonths,
            trackedDays: trackedDays,
            hasTodayWakeTime: hasTodayWakeTime,
            hasNightSleep: hasNightSleep
        )
        currentPhase = phaseReport?.phase ?? .baseline
        
        // 2. Baby Pattern
        babyPattern = patternAgent.analyze(
            records: sleepRecords,
            wakeRecords: wakeRecords,
            ageMonths: ageMonths
        )
        
        // 3. Overtired Level
        overtiredLevel = overtiredCalculator.calculateOvertiredLevel(
            sleepRecords: sleepRecords,
            wakeRecords: wakeRecords,
            ageMonths: ageMonths,
            now: now
        )
        overtireRisk = overtiredCalculator.overtireRisk
        
        // 4. Predictions (Pattern varsa)
        if let pattern = babyPattern {
            napPrediction = predictionAgent.predictNextNap(
                pattern: pattern,
                todayRecords: todayNaps,
                wakeTime: todayWakeTime,
                ageMonths: ageMonths,
                now: now
            )
            
            bedtimePrediction = predictionAgent.predictBedtime(
                pattern: pattern,
                todayNaps: todayNaps,
                ageMonths: ageMonths,
                now: now
            )
        }
        
        // 5. Insights (Pattern ve Phase varsa)
        if let pattern = babyPattern {
            insights = insightAgent.buildInsights(
                phase: currentPhase,
                pattern: pattern,
                overtireRisk: overtireRisk,
                trackedDays: trackedDays,
                babyName: memoryStore.getBabyName()
            )
        }
        
        lastUpdateTime = now
    }
    
    // MARK: - Record Management
    
    func recordSleep(
        date: Date,
        duration: Int,
        kind: SleepKind,
        parentNapID: UUID? = nil
    ) {
        var records = memoryStore.loadSleepRecords()
        let newRecord = SleepRecord(
            date: date,
            duration: duration,
            kind: kind,
            parentNapID: parentNapID
        )
        records.append(newRecord)
        memoryStore.saveSleepRecords(records)
        updateAllMetrics()
    }
    
    func recordWakeTime(day: Date, wakeTime: Date) {
        var records = memoryStore.loadDailyWakeRecords()
        let newRecord = DailyWakeRecord(day: day, wakeTime: wakeTime)
        records.append(newRecord)
        memoryStore.saveDailyWakeRecords(records)
        updateAllMetrics()
    }
    
    func deleteSleepRecord(_ recordID: UUID) {
        var records = memoryStore.loadSleepRecords()
        records.removeAll { $0.id == recordID }
        memoryStore.saveSleepRecords(records)
        updateAllMetrics()
    }
    
    // MARK: - Helper Functions
    
    private func calculateAgeMonths(birthDate: Date?, at now: Date) -> Int {
        guard let birthDate = birthDate else { return 0 }
        let components = calendar.dateComponents([.month], from: birthDate, to: now)
        return max(0, components.month ?? 0)
    }
    
    private func calculateTrackedDays(sleeps: [SleepRecord], wakeRecords: [DailyWakeRecord]) -> Int {
        let sleepDays = sleeps.map { calendar.startOfDay(for: $0.date) }
        let wakeDays = wakeRecords.map { calendar.startOfDay(for: $0.day) }
        return Set(sleepDays + wakeDays).count
    }
    
    private func hasTodayWakeTime(wakeRecords: [DailyWakeRecord], now: Date) -> Bool {
        return wakeRecords.contains { calendar.isDate($0.day, inSameDayAs: now) }
    }
    
    private func getTodayWakeTime(wakeRecords: [DailyWakeRecord], now: Date) -> Date? {
        return wakeRecords.first { calendar.isDate($0.day, inSameDayAs: now) }?.wakeTime
    }
    
    private func hasRecentNightSleep(sleepRecords: [SleepRecord]) -> Bool {
        let recentNights = sleepRecords.filter { $0.kind == .nightSleep && $0.date > Date().addingTimeInterval(-24 * 3600) }
        return !recentNights.isEmpty
    }
    
    // MARK: - Export Data
    
    func exportSleepData() -> [String: Any] {
        return [
            "phase": currentPhase.displayName,
            "overtiredLevel": overtiredLevel,
            "overtireRisk": overtireRisk.rawValue,
            "nextNapTime": napPrediction?.nextNapTime.ISO8601Format() ?? "N/A",
            "bedtimeStart": bedtimePrediction?.optimalBedtimeStart.ISO8601Format() ?? "N/A",
            "patternQuality": babyPattern?.dataQuality.rawValue ?? "unknown",
            "lastUpdate": lastUpdateTime?.ISO8601Format() ?? "N/A"
        ]
    }
}
