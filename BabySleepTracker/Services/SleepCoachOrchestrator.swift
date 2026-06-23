//
//  SleepCoachOrchestrator.swift
//  BabySleepTracker
//
//  Created by MacBook on 13.06.2026.
//

import Foundation

enum NextSleepKind {
    case nap
    case bedtime
}
enum DataQuality {
    case poor
    case fair
    case good
    case excellent
}

struct OrchestratedSnapshot {
       let generatedAt:        Date
       let babyName:           String
       let ageMonths:          Int

       // Ajanlardan gelen çıktılar
       let phase:              CoachPhase
       let readiness:          PhaseReadinessReport
       let pattern:            BabyPattern?
       let daytime:            DaytimePredictionAgent
       let night:              NightPredictionAgent
       let transition:         NapTransitionAssessment
       let insights:           SleepInsightBundle

       // Günlük uyku durumu
       let todayTotalMinutes:  Int
       let sleepStatus:        DailySleepStatus
       let nextSleepKind:      NextSleepKind


}

// MARK: - SleepCoachOrchestrator

@MainActor
final class SleepCoachOrchestrator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var snapshot: OrchestratedSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var llmResponse: LLMCoachResponse?
    @Published private(set) var isLLMLoading = false

    // MARK: - Agents

    private let phaseAgent:      PhaseAgentProtocol
    private let patternAgent:    PatternAgentProtocol
    private let daytimeAgent:    DaytimePredictionAgentProtocol
    private let nightAgent:      NightPredictionAgentProtocol
    private let transitionAgent: NapTransitionAgentProtocol
    private let insightAgent:    InsightAgentProtocol
    private let overtiredCalc:   OvertiredCalculator
    private let profileProvider: AgeBasedSleepProfileProviding
    private let llmAgent: SleepCoachLLMAgentProtocol

    
    // MARK: - Singleton

       static let shared = SleepCoachOrchestrator()

       // MARK: - Init

       init(
           phaseAgent:      PhaseAgentProtocol      = DefaultPhaseAgent(),
           patternAgent:    PatternAgentProtocol     = PatternAgent(),
           daytimeAgent:    DaytimePredictionAgentProtocol = DefaultDaytimePredictionAgent(),
           nightAgent:      NightPredictionAgentProtocol   = DefaultNightPredictionAgent(),
           transitionAgent: NapTransitionAgentProtocol     = DefaultNapTransitionAgent(),
           insightAgent:    InsightAgentProtocol     = DefaultInsightAgent(),
           llmAgent:        SleepCoachLLMAgentProtocol     = DefaultSleepCoachLLMAgent(),
           overtiredCalc:   OvertiredCalculator      = OvertiredCalculator(),
           profileProvider: AgeBasedSleepProfileProviding  = DefaultAgeBasedSleepProfileProvider()
       ) {
           self.phaseAgent      = phaseAgent
           self.patternAgent    = patternAgent
           self.daytimeAgent    = daytimeAgent
           self.nightAgent      = nightAgent
           self.transitionAgent = transitionAgent
           self.insightAgent    = insightAgent
           self.llmAgent        = llmAgent
           self.overtiredCalc   = overtiredCalc
           self.profileProvider = profileProvider
       }

       // MARK: - Generate Snapshot

       func generate(now: Date = Date()) {
           isLoading = true
           defer { isLoading = false }

           // 1. Veriyi yükle
           let records     = loadRecords()
           let wakeRecords = loadWakeRecords()
           let babyName    = loadBabyName()
           let ageMonths   = loadAgeMonths(at: now)
           
           // 2. Temel metrikler
                 let breaks    = records.filter { $0.kind == .break }
                 let todayRecs = records.filter { Calendar.current.isDateInToday($0.date) }

                 let trackedDays = countTrackedDays(
                     records:     records,
                     wakeRecords: wakeRecords
                 )

                 let todayTotal = todayRecs
                     .filter { $0.kind != .break }
                     .reduce(0) { $0 + $1.totalMinutes(breaks: breaks) }

                 // 3. Phase
                 let phase    = phaseAgent.currentPhase(
                     ageMonths:   ageMonths,
                     trackedDays: trackedDays
                 )

                 // Wake time ve gece uykusu sinyalleri
                 let hasTodayWake = wakeRecords.contains {
                     Calendar.current.isDateInToday($0.day)
                 }
                 let hasYesterdayNight: Bool = {
                     guard let yesterday = Calendar.current.date(
                         byAdding: .day, value: -1, to: now
                     ) else { return false }
                     return records.contains {
                         $0.kind == .nightSleep &&
                         Calendar.current.isDate($0.date, inSameDayAs: yesterday)
                     }
                 }()
                let readiness = phaseAgent.readinessReport(
                    ageMonths:            ageMonths,
                    trackedDays:          trackedDays,
                    hasTodayWakeTime:     hasTodayWake,
                    hasYesterdayNightSleep: hasYesterdayNight
                )

                // 4. Pattern — tooYoung değilse analiz et
                let pattern: BabyPattern?
                if case .tooYoung = phase {
                    pattern = nil
                } else {
                    pattern = patternAgent.analyze(
                        records:     records,
                        wakeRecords: wakeRecords,
                        ageMonths:   ageMonths,
                        now:         now
                    )
                }

                // 5. Daytime prediction
                let daytime = daytimeAgent.predictNextNap(
                    pattern:      pattern,
                    todayRecords: todayRecs,
                    wakeRecords:  wakeRecords,
                    ageMonths:    ageMonths,
                    trackedDays:  trackedDays,
                    now:          now
                )

                // 6. Night prediction
                let night = nightAgent.predictBedtime(
                    pattern:      pattern,
                    todayRecords: todayRecs,
                    wakeRecords:  wakeRecords,
                    ageMonths:    ageMonths,
                    trackedDays:  trackedDays,
                    now:          now
                )
           
           let todayDayNapsCount = todayRecs.filter { $0.kind == .dayNap }.count
           let profile = profileProvider.profile(forAgeMonths: ageMonths)
           let expectedNaps = profile.expectedNapCount

           let nextSleepKind: NextSleepKind = {
               // Henüz minimum nap sayısına ulaşılmadıysa kesinlikle nap
               if todayDayNapsCount < expectedNaps.lowerBound {
                   return .nap
               }
               // Maksimum nap sayısına ulaşıldıysa kesinlikle bedtime
               if todayDayNapsCount >= expectedNaps.upperBound {
                   return .bedtime
               }
               // Aradaysa — son nap cutoff saatine bak
               let cutoff = overtiredCalc.lastNapCutoffTime(ageMonths: ageMonths, on: now)
               return now < cutoff ? .nap : .bedtime
           }()

                // 7. Nap transition
                let transition = transitionAgent.assess(
                    records:     records,
                    wakeRecords: wakeRecords,
                    ageMonths:   ageMonths,
                    now:         now
                )

                // 8. Insights
                let insights = insightAgent.buildInsights(
                    phase:       phase,
                    pattern:     pattern,
                    trackedDays: trackedDays,
                    babyName:    babyName
                )

                // 9. Sleep status
                let sleepStatus = overtiredCalc.dailySleepStatus(
                    totalMinutes: todayTotal,
                    ageMonths:    ageMonths
                )

                // 10. Snapshot oluştur
                let result = OrchestratedSnapshot(
                    generatedAt:       now,
                    babyName:          babyName,
                    ageMonths:         ageMonths,
                    phase:             phase,
                    readiness:         readiness,
                    pattern:           pattern,
                    daytime:           daytime,
                    night:             night,
                    transition:        transition,
                    insights:          insights,
                    todayTotalMinutes: todayTotal,
                    sleepStatus:       sleepStatus,
                    nextSleepKind: nextSleepKind
                )
                self.snapshot = result 
                let trigger = determineTrigger(
                    records:    records,
                    snapshot:   result,
                    previous:   snapshot)
           
           if trigger != nil {
               Task {
                   await callLLM(snapshot: result, records: records, trigger: trigger!)
               }
           }
         
       }

            // MARK: - Data Loaders

            private func loadRecords() -> [SleepRecord] {
                guard let data = UserDefaults.standard.data(forKey: "sleepRecords"),
                      let decoded = try? JSONDecoder().decode([SleepRecord].self, from: data)
                else { return [] }
                return decoded
            }

            private func loadWakeRecords() -> [DailyWakeRecord] {
                guard let data = UserDefaults.standard.data(forKey: "dailyWakeRecords_v1"),
                      let decoded = try? JSONDecoder().decode([DailyWakeRecord].self, from: data)
                else { return [] }
                return decoded
            }

            private func loadBabyName() -> String {
                let name = UserDefaults.standard.string(forKey: "babyName")?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return name.isEmpty ? "Baby" : name
            }

            private func loadAgeMonths(at date: Date) -> Int {
                let birthDateKey: Date?
                if let saved = UserDefaults.standard.object(forKey: "birthDateKey") as? Date {
                    birthDateKey = saved
                } else if let seconds = UserDefaults.standard.object(forKey: "birthDateKey") as? Double {
                    birthDateKey = Date(timeIntervalSince1970: seconds)
                } else {
                    birthDateKey = nil
                }
                guard let birth = birthDateKey else { return 9 }
                return max(0, Calendar.current.dateComponents([.month], from: birth, to: date).month ?? 9)
            }

            private func countTrackedDays(
                records:     [SleepRecord],
                wakeRecords: [DailyWakeRecord]
            ) -> Int {
                let sleepDays = records.map { Calendar.current.startOfDay(for: $0.date) }
                let wakeDays  = wakeRecords.map { Calendar.current.startOfDay(for: $0.day) }
                return Set(sleepDays + wakeDays).count
            }

            // MARK: - Cache

            private func cache(_ snapshot: OrchestratedSnapshot) {
                // Sadece basit değerleri cache'le — Date'ler UserDefaults'a direkt gider
                UserDefaults.standard.set(
                    snapshot.generatedAt.timeIntervalSince1970,
                    forKey: "orchestrator_lastGenerated"
                )
            }
    
    // MARK: - Data Quality

    private func quality(for days: Int) -> DataQuality {
        switch days {
        case 0...3:  return .poor
        case 4...7:  return .fair
        case 8...13: return .good
        default:     return .excellent
        }
        
    }
    // MARK: - LLM

    private func callLLM(
        snapshot: OrchestratedSnapshot,
        records:  [SleepRecord],
        trigger:  LLMTrigger
    ) async {
        isLLMLoading = true
        defer { isLLMLoading = false }

        let response = await llmAgent.generateInsight(
            snapshot: snapshot,
            records:  records,
            trigger:  trigger
        )

        if let response {
            llmResponse = response
            cacheLLMResponse(response)
        }
    }

    private func determineTrigger(
        records:  [SleepRecord],
        snapshot: OrchestratedSnapshot,
        previous: OrchestratedSnapshot?
    ) -> LLMTrigger? {

        // Daha önce hiç LLM çağrısı yapılmadıysa
        guard let lastGenerated = loadLastLLMDate() else {
            return .newDayStarted
        }

        let cal   = Calendar.current
        let now   = Date()

        // Yeni gün başladıysa
        if !cal.isDate(lastGenerated, inSameDayAs: now) {
            return .newDayStarted
        }

        // Yeni nap eklendiyse — önceki snapshot'tan fazla kayıt var mı?
        let prevCount    = previous?.todayTotalMinutes ?? 0
        let currentCount = snapshot.todayTotalMinutes
        if currentCount > prevCount {
            // Kısa nap mı?
            let todayNaps = records
                .filter { $0.kind == .dayNap && cal.isDateInToday($0.date) }
                .sorted { $0.date > $1.date }

            if let lastNap = todayNaps.first, lastNap.duration < 45 {
                return .shortNapDetected
            }
            return .napLogged
        }

        // Transition sinyali güçlendiyse
        if snapshot.transition.signalStrength == .strong {
            return .transitionSignalHigh
        }

        // Haftalık review — son LLM'den 7 gün geçtiyse
        let daysSinceLast = cal.dateComponents([.day], from: lastGenerated, to: now).day ?? 0
        if daysSinceLast >= 7 {
            return .weeklyReview
        }

        // Trigger yok — LLM çağırma
        return nil
    }

    // MARK: - LLM Cache

    private func cacheLLMResponse(_ response: LLMCoachResponse) {
        UserDefaults.standard.set(
            response.generatedAt.timeIntervalSince1970,
            forKey: "llm_lastGenerated"
        )
        // Mesajları da sakla
        UserDefaults.standard.set(response.coachMessage,   forKey: "llm_coachMessage")
        UserDefaults.standard.set(response.patternInsight, forKey: "llm_patternInsight")
        UserDefaults.standard.set(response.confidenceNote, forKey: "llm_confidenceNote")
        if let alert = response.alert {
            UserDefaults.standard.set(alert, forKey: "llm_alert")
        }
    }

    private func loadLastLLMDate() -> Date? {
        let ts = UserDefaults.standard.double(forKey: "llm_lastGenerated")
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // Uygulama açılışında cached LLM response'u yükle
    func loadCachedLLMResponse() {
        guard let coachMessage = UserDefaults.standard.string(forKey: "llm_coachMessage"),
              !coachMessage.isEmpty,
              let lastDate = loadLastLLMDate()
        else { return }

        // 24 saatten eski cache'i yükleme
        guard Date().timeIntervalSince(lastDate) < 86400 else { return }

        llmResponse = LLMCoachResponse(
            patternInsight: UserDefaults.standard.string(forKey: "llm_patternInsight") ?? "",
            coachMessage:   coachMessage,
            alert:          UserDefaults.standard.string(forKey: "llm_alert"),
            confidenceNote: UserDefaults.standard.string(forKey: "llm_confidenceNote") ?? "",
            generatedAt:    lastDate
        )
    }

    // Manuel refresh — kullanıcı istediğinde
    func refreshLLM() {
        guard let current = snapshot else { return }
        let records = loadRecords()
        Task {
            await callLLM(
                snapshot: current,
                records:  records,
                trigger:  .manualRefresh
            )
        }
    }
        }

