import Foundation

// MARK: - Phase Definitions

enum CoachPhase: Equatable {
    case tooYoung          // 0-4 ay: sadece bilgilendirme
    case baseline          // 4ay+ ilk gün: yaşa göre genel
    case learning(day: Int) // 1-13. gün: veri toplama
    case personalized      // 14+ gün: tam kişiselleştirme
    
    var displayName: String {
        switch self {
        case .tooYoung:
            return "Too Young"
        case .baseline:
            return "Age Baseline"
        case .learning(let day):
            return "Learning \(day)/14"
        case .personalized:
            return "Personalized"
        }
    }
    
    var description: String {
        switch self {
        case .tooYoung:
            return "Your baby is too young for sleep predictions. Focus on establishing routines."
        case .baseline:
            return "Using age-based guidelines until we learn your baby's patterns."
        case .learning(let day):
            return "Learning from \(day) day\(day == 1 ? "" : "s") of data. Keep logging for personalization."
        case .personalized:
            return "Fully personalized predictions based on your baby's unique sleep rhythm."
        }
    }
}

// MARK: - Missing Signals

enum MissingSignal: String, CaseIterable {
    case wakeTime = "Add today's wake-up time"
    case nightSleep = "Log last night's sleep"
    case consecutiveDays = "Track more consecutive days"
    
    var priority: Int {
        switch self {
        case .wakeTime: return 1
        case .nightSleep: return 2
        case .consecutiveDays: return 3
        }
    }
    
    var detail: String {
        switch self {
        case .wakeTime:
            return "Wake time is the strongest signal for predicting naps."
        case .nightSleep:
            return "Night sleep data helps understand overall sleep needs."
        case .consecutiveDays:
            return "More consecutive tracked days unlock personalization."
        }
    }
}

// MARK: - Phase Readiness Report

struct PhaseReadinessReport {
    let phase: CoachPhase
    let daysUntilPersonalized: Int
    let missingSignals: [MissingSignal]
    let confidence: Int
    let progressPercentage: Double
    
    var isReadyForNextPhase: Bool {
        daysUntilPersonalized <= 0
    }
}

// MARK: - PhaseAgent Protocol

protocol PhaseAgentProtocol {
    func currentPhase(ageMonths: Int, trackedDays: Int) -> CoachPhase
    func readinessReport(
        ageMonths: Int,
        trackedDays: Int,
        hasTodayWakeTime: Bool,
        hasNightSleep: Bool
    ) -> PhaseReadinessReport
}

// MARK: - PhaseAgent Implementation

final class PhaseAgent: NSObject, ObservableObject, PhaseAgentProtocol {
    @Published var currentPhase: CoachPhase = .baseline
    @Published var readinessReport: PhaseReadinessReport?
    
    private let memoryStore = SleepMemoryStore.shared
    private let calendar = Calendar.current
    
    override init() {
        super.init()
    }
    
    // MARK: - Phase Determination
    
    func currentPhase(ageMonths: Int, trackedDays: Int) -> CoachPhase {
        // Yaş kontrolü: 0-4 ay
        if ageMonths < 4 {
            return .tooYoung
        }
        
        // Veri yok: baseline
        if trackedDays == 0 {
            return .baseline
        }
        
        // Learning phase: 1-13 gün
        if trackedDays < 14 {
            return .learning(day: trackedDays)
        }
        
        // Personalized: 14+ gün
        return .personalized
    }
    
    // MARK: - Readiness Report
    
    func readinessReport(
        ageMonths: Int,
        trackedDays: Int,
        hasTodayWakeTime: Bool,
        hasNightSleep: Bool
    ) -> PhaseReadinessReport {
        let phase = currentPhase(ageMonths: ageMonths, trackedDays: trackedDays)
        var missingSignals: [MissingSignal] = []
        var confidence = 54
        
        // Wake time kontrol
        if !hasTodayWakeTime {
            missingSignals.append(.wakeTime)
        } else {
            confidence += 8
        }
        
        // Night sleep kontrol
        if !hasNightSleep && trackedDays > 0 {
            missingSignals.append(.nightSleep)
        }
        
        // Consecutive days kontrol
        if trackedDays < 14 {
            missingSignals.append(.consecutiveDays)
        }
        
        // Confidence hesaplaması
        confidence += min(trackedDays, 14) * 2
        if phase == .personalized {
            confidence += 4
        }
        confidence = min(94, confidence)
        
        // Progress
        let progressPercentage = Double(min(trackedDays, 14)) / 14.0 * 100
        let daysUntilPersonalized = max(0, 14 - trackedDays)
        
        let report = PhaseReadinessReport(
            phase: phase,
            daysUntilPersonalized: daysUntilPersonalized,
            missingSignals: missingSignals.sorted { $0.priority < $1.priority },
            confidence: confidence,
            progressPercentage: progressPercentage
        )
        
        self.readinessReport = report
        self.currentPhase = phase
        memoryStore.setCurrentPhase(phase)
        
        return report
    }
    
    // MARK: - Phase Info for UI
    
    func phaseLabel(for phase: CoachPhase) -> String {
        switch phase {
        case .tooYoung:
            return "AGE TOO YOUNG"
        case .baseline:
            return "AGE BASELINE"
        case .learning(let day):
            return "LEARNING \(min(day, 14))/14"
        case .personalized:
            return "PERSONALIZED"
        }
    }
    
    func phaseDescription(for phase: CoachPhase) -> String {
        return phase.description
    }
    
    func nextPhaseHint(for phase: CoachPhase) -> String? {
        switch phase {
        case .tooYoung:
            return "Your baby will qualify for predictions at 4 months old."
        case .baseline:
            return "Add wake times and sleep records to start learning your baby's patterns."
        case .learning(let day):
            let remaining = 14 - day
            return "Keep logging for \(remaining) more day\(remaining == 1 ? "" : "s") to unlock personalization."
        case .personalized:
            return nil // No next phase
        }
    }
}
