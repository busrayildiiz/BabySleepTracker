import Foundation

// MARK: - Alert Definitions

enum AlertSeverity {
    case info
    case warning
    case critical
}

enum AlertAction {
    case addWakeTime
    case addNap
    case addNightSleep
}

// MARK: - Sleep Alert

struct SleepAlert {
    let severity: AlertSeverity
    let message: String
    let actionTitle: String?
    let actionType: AlertAction?
}

// MARK: - Sleep Insight Bundle

struct SleepInsightBundle {
    let headline: String                // Ana mesaj (örn. "Harika gün!")
    let coachTip: String               // Günün koçluk mesajı
    let alerts: [SleepAlert]           // Kritik uyarılar
    let weeklyPattern: String?         // 7+ günden sonra gelen haftalık yorum
    let progressMessage: String        // "X günde Y kez takip ettin" gibi
}

// MARK: - Insight Agent Protocol

protocol InsightAgentProtocol {
    func buildInsights(
        phase: CoachPhase,
        pattern: BabyPattern?,
        overtireRisk: OvertiredCalculator.OvertireRisk,
        trackedDays: Int,
        babyName: String
    ) -> SleepInsightBundle
}

// MARK: - Insight Agent Implementation

final class InsightAgent: NSObject, ObservableObject, InsightAgentProtocol {
    @Published var currentInsights: SleepInsightBundle?
    
    override init() {
        super.init()
    }
    
    // MARK: - Build Insights
    
    func buildInsights(
        phase: CoachPhase,
        pattern: BabyPattern?,
        overtireRisk: OvertiredCalculator.OvertireRisk,
        trackedDays: Int,
        babyName: String
    ) -> SleepInsightBundle {
        // 1. Headline
        let headline = generateHeadline(
            phase: phase,
            overtireRisk: overtireRisk,
            trackedDays: trackedDays
        )
        
        // 2. Coach Tip
        let coachTip = generateCoachTip(
            phase: phase,
            pattern: pattern,
            overtireRisk: overtireRisk,
            babyName: babyName
        )
        
        // 3. Alerts
        let alerts = generateAlerts(
            phase: phase,
            pattern: pattern,
            overtireRisk: overtireRisk,
            babyName: babyName
        )
        
        // 4. Weekly Pattern (7+ gün varsa)
        let weeklyPattern = pattern?.sampleSize ?? 0 >= 7 ?
            generateWeeklyPattern(pattern: pattern!, babyName: babyName) : nil
        
        // 5. Progress Message
        let progressMessage = generateProgressMessage(
            trackedDays: trackedDays,
            phase: phase,
            babyName: babyName
        )
        
        let bundle = SleepInsightBundle(
            headline: headline,
            coachTip: coachTip,
            alerts: alerts,
            weeklyPattern: weeklyPattern,
            progressMessage: progressMessage
        )
        
        currentInsights = bundle
        return bundle
    }
    
    // MARK: - Headline Generation
    
    private func generateHeadline(
        phase: CoachPhase,
        overtireRisk: OvertiredCalculator.OvertireRisk,
        trackedDays: Int
    ) -> String {
        // Overtire risk'e göre
        switch overtireRisk {
        case .criticallyTired:
            return "🚨 Critical: Immediate nap needed"
        case .significant:
            return "⚠️ Very tired: Consider an early nap"
        case .moderate:
            return "😴 Getting tired: Nap time soon"
        case .slightlyTired:
            return "👀 Slightly tired: Watch for cues"
        case .healthy:
            return "✨ Well-rested: Great job!"
        }
    }
    
    // MARK: - Coach Tip Generation
    
    private func generateCoachTip(
        phase: CoachPhase,
        pattern: BabyPattern?,
        overtireRisk: OvertiredCalculator.OvertireRisk,
        babyName: String
    ) -> String {
        // Overtire uyarısı en önemli
        if overtireRisk == .critical || overtireRisk == .significant {
            return "\(babyName) is showing signs of overtiredness. An immediate nap will help reset their system."
        }
        
        // Phase tarafından
        switch phase {
        case .tooYoung:
            return "At this age, focus on following \(babyName)'s natural rhythms rather than a fixed schedule."
        case .baseline:
            return "Keep logging \(babyName)'s sleep. Each record helps build their unique sleep profile."
        case .learning(let day):
            let remaining = 14 - day
            return "Just \(remaining) more day\(remaining == 1 ? "" : "s") to unlock personalized predictions!"
        case .personalized:
            if let hour = pattern?.bestFirstNapHour {
                let hourStr = formatHour(hour)
                return "\(babyName)'s longest naps typically happen around \(hourStr). Naps at this time tend to last ~\(pattern?.bestNapExtraMinutes ?? 15) minutes longer."
            }
            return "You've unlocked personalized predictions! The model will keep improving as you log more sleep."
        }
    }
    
    // MARK: - Alerts Generation
    
    private func generateAlerts(
        phase: CoachPhase,
        pattern: BabyPattern?,
        overtireRisk: OvertiredCalculator.OvertireRisk,
        babyName: String
    ) -> [SleepAlert] {
        var alerts: [SleepAlert] = []
        
        // Overtire critical alert
        if overtireRisk == .criticallyTired {
            alerts.append(SleepAlert(
                severity: .critical,
                message: "\(babyName) has been awake too long. An immediate nap is strongly recommended.",
                actionTitle: "Log nap",
                actionType: .addNap
            ))
        }
        
        // Phase-specific alerts
        switch phase {
        case .baseline:
            alerts.append(SleepAlert(
                severity: .warning,
                message: "Add today's wake-up time for more accurate predictions.",
                actionTitle: "Add wake time",
                actionType: .addWakeTime
            ))
        case .learning:
            if pattern == nil {
                alerts.append(SleepAlert(
                    severity: .info,
                    message: "Keep logging sleep and wake times. Patterns emerge after ~7 days.",
                    actionTitle: nil,
                    actionType: nil
                ))
            }
        default:
            break
        }
        
        // Data quality alert
        if let pattern = pattern, pattern.dataQuality == .poor {
            alerts.append(SleepAlert(
                severity: .info,
                message: "More data improves predictions. Log \(7 - pattern.sampleSize) more days for better insights.",
                actionTitle: nil,
                actionType: nil
            ))
        }
        
        return alerts
    }
    
    // MARK: - Weekly Pattern Generation
    
    private func generateWeeklyPattern(pattern: BabyPattern, babyName: String) -> String {
        var insights: [String] = []
        
        // Nap patterns
        if let bestHour = pattern.bestFirstNapHour {
            let hourStr = formatHour(bestHour)
            insights.append("Best nap time: \(hourStr)")
        }
        
        // Wake window trend
        switch pattern.wakingWindowTrend {
        case .increasing:
            insights.append("\(babyName)'s wake window is increasing (getting more awake-time tolerance)")
        case .decreasing:
            insights.append("\(babyName)'s wake window is decreasing (needs earlier naps)")
        case .stable:
            insights.append("Wake window is stable and consistent")
        case .insufficient:
            break
        }
        
        // Nap duration trend
        switch pattern.napDurationTrend {
        case .increasing:
            insights.append("Naps are getting longer")
        case .decreasing:
            insights.append("Naps are getting shorter")
        case .stable:
            insights.append("Nap duration is consistent")
        case .insufficient:
            break
        }
        
        return insights.joined(separator: " • ")
    }
    
    // MARK: - Progress Message Generation
    
    private func generateProgressMessage(
        trackedDays: Int,
        phase: CoachPhase,
        babyName: String
    ) -> String {
        switch phase {
        case .tooYoung:
            return "\(babyName) will be eligible for predictions at 4 months."
        case .baseline:
            return "No tracked days yet. Start by logging \(babyName)'s sleep and wake times."
        case .learning(let day):
            let remaining = 14 - day
            return "You've tracked \(day) day\(day == 1 ? "" : "s"). \(remaining) more day\(remaining == 1 ? "" : "s") to personalization!"
        case .personalized:
            return "Personalized! \(babyName)'s data is being used for all predictions. \(trackedDays) days tracked."
        }
    }
    
    // MARK: - Helper
    
    private func formatHour(_ hour: Int) -> String {
        let ampm = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour) \(ampm)"
    }
}
