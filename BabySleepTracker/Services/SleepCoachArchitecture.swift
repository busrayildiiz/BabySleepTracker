import Foundation

struct DailyWakeRecord: Identifiable, Codable {
    let id: UUID
    let day: Date
    let wakeTime: Date

    init(id: UUID = UUID(), day: Date, wakeTime: Date) {
        self.id = id
        self.day = day
        self.wakeTime = wakeTime
    }
}

enum SleepCoachMode: String, Codable {
    case baseline
    case learning
    case personalized
}

struct SleepGuideline: Codable {
    let minimumDailyMinutes: Int
    let maximumDailyMinutes: Int
    let sourceName: String
    let sourceURL: String
}

struct SleepCoachPrediction: Codable {
    let recommendedTime: Date
    let windowStart: Date
    let windowEnd: Date
    let confidence: Int
    let wakeWindowMinutes: Int
    let expectedNapMinutes: Int
    let mode: SleepCoachMode
    let trackedDays: Int
    let anchorTime: Date
    let hasTodayWakeTime: Bool
    let reasons: [String]
}

struct SleepCoachInsight: Identifiable, Codable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let value: String
    let tone: String
}

struct SleepCoachPlanItem: Identifiable, Codable {
    let id: String
    let time: Date
    let title: String
    let detail: String
    let icon: String
    let isPrediction: Bool
}

struct SleepCoachSnapshot: Codable {
    let generatedAt: Date
    let babyName: String
    let ageMonths: Int
    let guideline: SleepGuideline
    let prediction: SleepCoachPrediction
    let plan: [SleepCoachPlanItem]
    let insights: [SleepCoachInsight]
    let coachTip: String
}

private struct PersonalSleepProfile {
    let observedWakeWindow: Int?
    let averageNapMinutes: Int?
    let bestNapHour: Int?
    let bestNapExtraMinutes: Int?
    let bedtimeShiftMinutes: Int?
    let weekOverWeekNapChange: Int?
}

protocol PediatricSleepGuidelineProviding {
    func guideline(forAgeMonths ageMonths: Int) -> SleepGuideline
}

protocol WakeWindowBaselineProviding {
    func wakeWindow(forAgeMonths ageMonths: Int) -> ClosedRange<Int>
}


final class SleepCoachService {
    static let shared = SleepCoachService()

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let guidelineAgent: PediatricSleepGuidelineProviding
    private let baselineAgent: WakeWindowBaselineProviding

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        guidelineAgent: PediatricSleepGuidelineProviding = AAPSleepGuidelineAgent(),
        baselineAgent: WakeWindowBaselineProviding = WakeWindowBaselineAgent()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.guidelineAgent = guidelineAgent
        self.baselineAgent = baselineAgent
    }

    func generateSnapshot(now: Date = Date()) -> SleepCoachSnapshot {
        let records = load([SleepRecord].self, key: "sleepRecords") ?? []
        let wakeRecords = load([DailyWakeRecord].self, key: "dailyWakeRecords_v1") ?? []
        let breaks = records.filter { $0.kind == .break }
        let sleeps = records.filter { $0.kind != .break }
        let dayNaps = sleeps.filter { $0.kind == .dayNap }
        let babyName = normalizedBabyName
        let ageMonths = babyAgeMonths(at: now)
        let guideline = guidelineAgent.guideline(forAgeMonths: ageMonths)
        let baseline = baselineAgent.wakeWindow(forAgeMonths: ageMonths)
        let trackedDays = trackedDayCount(sleeps: sleeps, wakeRecords: wakeRecords)
        let profile = analyze(
            dayNaps: dayNaps,
            nightSleeps: sleeps.filter { $0.kind == .nightSleep },
            breaks: breaks,
            wakeRecords: wakeRecords,
            now: now
        )
        let anchor = predictionAnchor(dayNaps: dayNaps, wakeRecords: wakeRecords, now: now)
        let mode: SleepCoachMode = trackedDays >= 14 ? .personalized : (trackedDays > 0 ? .learning : .baseline)
        let wakeWindow = blendedWakeWindow(
            baseline: baseline,
            observed: profile.observedWakeWindow,
            trackedDays: trackedDays
        )
        let recommendedTime = calendar.date(byAdding: .minute, value: wakeWindow, to: anchor.time) ?? now
        let windowRadius = mode == .personalized ? 10 : 15
        let confidence = confidence(
            mode: mode,
            trackedDays: trackedDays,
            hasWakeTime: anchor.hasTodayWakeTime,
            hasObservedWindow: profile.observedWakeWindow != nil
        )
        let expectedNap = profile.averageNapMinutes ?? 90
        let prediction = SleepCoachPrediction(
            recommendedTime: recommendedTime,
            windowStart: calendar.date(byAdding: .minute, value: -windowRadius, to: recommendedTime) ?? recommendedTime,
            windowEnd: calendar.date(byAdding: .minute, value: windowRadius, to: recommendedTime) ?? recommendedTime,
            confidence: confidence,
            wakeWindowMinutes: wakeWindow,
            expectedNapMinutes: expectedNap,
            mode: mode,
            trackedDays: trackedDays,
            anchorTime: anchor.time,
            hasTodayWakeTime: anchor.hasTodayWakeTime,
            reasons: reasons(
                mode: mode,
                trackedDays: trackedDays,
                hasWakeTime: anchor.hasTodayWakeTime,
                ageMonths: ageMonths,
                guideline: guideline
            )
        )
        let snapshot = SleepCoachSnapshot(
            generatedAt: now,
            babyName: babyName,
            ageMonths: ageMonths,
            guideline: guideline,
            prediction: prediction,
            plan: buildPlan(
                prediction: prediction,
                dayNaps: dayNaps,
                wakeRecords: wakeRecords,
                now: now
            ),
            insights: buildInsights(
                profile: profile,
                prediction: prediction,
                babyName: babyName
            ),
            coachTip: coachTip(
                profile: profile,
                prediction: prediction,
                babyName: babyName
            )
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: "sleepCoachSnapshot_v1")
        }
        return snapshot
    }

    private var normalizedBabyName: String {
        let value = defaults.string(forKey: "babyName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Baby" : value
    }

    private func babyAgeMonths(at date: Date) -> Int {
        let birthDate: Date?
        if let savedDate = defaults.object(forKey: "babyBirthDate") as? Date {
            birthDate = savedDate
        } else if let seconds = defaults.object(forKey: "babyBirthDate") as? Double {
            birthDate = Date(timeIntervalSince1970: seconds)
        } else {
            birthDate = nil
        }
        guard let birthDate else { return 9 }
        return max(0, calendar.dateComponents([.month], from: birthDate, to: date).month ?? 9)
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return decoded
    }

    private func trackedDayCount(sleeps: [SleepRecord], wakeRecords: [DailyWakeRecord]) -> Int {
        let sleepDays = sleeps.map { calendar.startOfDay(for: $0.date) }
        let wakeDays = wakeRecords.map { calendar.startOfDay(for: $0.day) }
        return Set(sleepDays + wakeDays).count
    }

    private func predictionAnchor(
        dayNaps: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        now: Date
    ) -> (time: Date, hasTodayWakeTime: Bool) {
        let todayNaps = dayNaps
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date < $1.date }
        if let lastNap = todayNaps.last {
            let end = calendar.date(byAdding: .minute, value: lastNap.duration, to: lastNap.date) ?? lastNap.date
            return (end, true)
        }
        if let wake = wakeRecords
            .filter({ calendar.isDate($0.day, inSameDayAs: now) })
            .max(by: { $0.wakeTime < $1.wakeTime }) {
            return (wake.wakeTime, true)
        }
        // Fallback: bir sonraki sabah 07:00 değil, TODAY'in mantıklı saati
        let today = calendar.startOfDay(for: now)
        let morning7 = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today) ?? now

        // Eğer 07:00 geçtiyse now'u kullan, geçmediyse 07:00
        let fallback = now > morning7 ? now : morning7
        return (fallback, false)
    }

    private func analyze(
        dayNaps: [SleepRecord],
        nightSleeps: [SleepRecord],
        breaks: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        now: Date
    ) -> PersonalSleepProfile {
        let sortedNaps = dayNaps.sorted { $0.date < $1.date }
        var wakeWindows: [Int] = []

        for nap in sortedNaps {
            let dayStart = calendar.startOfDay(for: nap.date)
            let previousNap = sortedNaps.last {
                $0.date < nap.date && calendar.isDate($0.date, inSameDayAs: nap.date)
            }
            let anchor: Date?
            if let previousNap {
                anchor = calendar.date(byAdding: .minute, value: previousNap.duration, to: previousNap.date)
            } else {
                anchor = wakeRecords.last {
                    calendar.isDate($0.day, inSameDayAs: dayStart) && $0.wakeTime <= nap.date
                }?.wakeTime
            }
            if let anchor {
                let minutes = Int(nap.date.timeIntervalSince(anchor) / 60)
                if (30...600).contains(minutes) { wakeWindows.append(minutes) }
            }
        }

        let napDurations = sortedNaps.map { $0.totalMinutes(breaks: breaks) }.filter { $0 > 0 }
        let groupedByHour = Dictionary(grouping: sortedNaps) { calendar.component(.hour, from: $0.date) }
        let hourAverages = groupedByHour.mapValues { naps in
            naps.map { $0.totalMinutes(breaks: breaks) }.reduce(0, +) / max(naps.count, 1)
        }
        let bestHour = hourAverages.max { $0.value < $1.value }
        let overallAverage = napDurations.isEmpty ? nil : napDurations.reduce(0, +) / napDurations.count

        let lastSevenStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let currentDurations = sortedNaps.filter { $0.date >= lastSevenStart }
            .map { $0.totalMinutes(breaks: breaks) }
        let previousDurations = sortedNaps.filter { $0.date >= previousStart && $0.date < lastSevenStart }
            .map { $0.totalMinutes(breaks: breaks) }
        let currentAverage = average(currentDurations)
        let previousAverage = average(previousDurations)
        let weeklyChange = currentAverage.flatMap { current in previousAverage.map { current - $0 } }

        return PersonalSleepProfile(
            observedWakeWindow: median(wakeWindows),
            averageNapMinutes: overallAverage,
            bestNapHour: bestHour?.key,
            bestNapExtraMinutes: bestHour.flatMap { best in overallAverage.map { max(0, best.value - $0) } },
            bedtimeShiftMinutes: estimatedBedtimeShift(dayNaps: sortedNaps, nightSleeps: nightSleeps, breaks: breaks),
            weekOverWeekNapChange: weeklyChange
        )
    }

    private func blendedWakeWindow(
        baseline: ClosedRange<Int>,
        observed: Int?,
        trackedDays: Int
    ) -> Int {
        let baselineCenter = (baseline.lowerBound + baseline.upperBound) / 2
        guard let observed else { return baselineCenter }
        let weight = min(1, Double(trackedDays) / 14.0)
        let blended = Double(baselineCenter) * (1 - weight) + Double(observed) * weight
        return max(baseline.lowerBound - 30, min(baseline.upperBound + 45, Int(blended.rounded())))
    }

    private func confidence(
        mode: SleepCoachMode,
        trackedDays: Int,
        hasWakeTime: Bool,
        hasObservedWindow: Bool
    ) -> Int {
        var value = 54 + min(trackedDays, 14) * 2
        if hasWakeTime { value += 8 }
        if hasObservedWindow { value += 5 }
        if mode == .personalized { value += 4 }
        return min(94, value)
    }

    private func reasons(
        mode: SleepCoachMode,
        trackedDays: Int,
        hasWakeTime: Bool,
        ageMonths: Int,
        guideline: SleepGuideline
    ) -> [String] {
        let anchorReason = hasWakeTime
            ? "Calculated from today's latest wake-up time"
            : "Add today's wake-up time to improve accuracy"
        let learningReason: String
        if mode == .personalized {
            learningReason = "Personalized from \(trackedDays) days of sleep patterns"
        } else {
            learningReason = "Age baseline blended with \(trackedDays) tracked day\(trackedDays == 1 ? "" : "s")"
        }
        let guidelineReason: String
        if guideline.minimumDailyMinutes == 0 {
            guidelineReason = "AAP-endorsed guidance has no fixed sleep-duration target before 4 months"
        } else {
            let minHours = guideline.minimumDailyMinutes / 60
            let maxHours = guideline.maximumDailyMinutes / 60
            guidelineReason = "Daily sleep is checked against the \(minHours)-\(maxHours)h AAP-endorsed range for age \(ageMonths)m"
        }
        return [
            anchorReason,
            learningReason,
            guidelineReason
        ]
    }

    private func buildPlan(
        prediction: SleepCoachPrediction,
        dayNaps: [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        now: Date
    ) -> [SleepCoachPlanItem] {
        var items: [SleepCoachPlanItem] = []
        if let wake = wakeRecords.first(where: { calendar.isDate($0.day, inSameDayAs: now) }) {
            items.append(SleepCoachPlanItem(
                id: "wake",
                time: wake.wakeTime,
                title: "Wake up",
                detail: "Day started",
                icon: "sun.max.fill",
                isPrediction: false
            ))
        }
        let todayNaps = dayNaps
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date < $1.date }
        for (index, nap) in todayNaps.prefix(2).enumerated() {
            items.append(SleepCoachPlanItem(
                id: "nap-\(nap.id)",
                time: nap.date,
                title: "Nap \(index + 1)",
                detail: "\(nap.duration / 60)h \(nap.duration % 60)m",
                icon: "moon.fill",
                isPrediction: false
            ))
        }
        items.append(SleepCoachPlanItem(
            id: "prediction",
            time: prediction.recommendedTime,
            title: "Next nap",
            detail: "Best window",
            icon: "moon.stars.fill",
            isPrediction: true
        ))
        return items
    }

    private func buildInsights(
        profile: PersonalSleepProfile,
        prediction: SleepCoachPrediction,
        babyName: String
    ) -> [SleepCoachInsight] {
        var result = [
            SleepCoachInsight(
                id: "wake-window",
                icon: "clock",
                title: "Optimal wake window",
                detail: "\(babyName) is most likely to fall asleep near this interval.",
                value: duration(prediction.wakeWindowMinutes),
                tone: "purple"
            )
        ]

        if let hour = profile.bestNapHour {
            let end = (hour + 2) % 24
            let extra = profile.bestNapExtraMinutes ?? 0
            result.append(SleepCoachInsight(
                id: "best-time",
                icon: "calendar",
                title: "Best nap time",
                detail: extra > 5
                    ? "Naps near this time last about \(extra)m longer."
                    : "\(babyName)'s longest naps often begin here.",
                value: "\(clockHour(hour)) - \(clockHour(end))",
                tone: "green"
            ))
        } else {
            result.append(SleepCoachInsight(
                id: "best-time",
                icon: "calendar",
                title: "Best nap time",
                detail: "This insight appears as more naps are recorded.",
                value: "Learning",
                tone: "green"
            ))
        }

        if let shift = profile.bedtimeShiftMinutes, shift >= 10 {
            result.append(SleepCoachInsight(
                id: "bedtime-shift",
                icon: "moon.zzz",
                title: "Bedtime connection",
                detail: "Longer daytime sleep is linked with a later bedtime.",
                value: "+\(shift)m",
                tone: "pink"
            ))
        } else {
            let change = profile.weekOverWeekNapChange ?? 0
            result.append(SleepCoachInsight(
                id: "quality",
                icon: "heart",
                title: "Nap quality trend",
                detail: change == 0 ? "Keep logging to reveal week-to-week changes." : "Average nap length changed this week.",
                value: change == 0 ? "Learning" : "\(change > 0 ? "+" : "")\(change)m",
                tone: "pink"
            ))
        }
        return result
    }

    private func coachTip(
        profile: PersonalSleepProfile,
        prediction: SleepCoachPrediction,
        babyName: String
    ) -> String {
        if !prediction.hasTodayWakeTime {
            return "Add \(babyName)'s wake-up time first. It is the strongest signal for today's next nap."
        }
        if prediction.mode != .personalized {
            let remaining = max(0, 14 - prediction.trackedDays)
            return "Keep logging wake-ups and naps. \(remaining) more tracked day\(remaining == 1 ? "" : "s") will unlock fully personalized predictions."
        }
        if let shift = profile.bedtimeShiftMinutes, shift >= 10 {
            return "A longer daytime nap may shift bedtime by about \(shift) minutes. Use the prediction window as a guide, not a strict deadline."
        }
        return "Aim for the predicted window, then follow \(babyName)'s sleepy cues. The model will keep adapting after every record."
    }

    private func estimatedBedtimeShift(
        dayNaps: [SleepRecord],
        nightSleeps: [SleepRecord],
        breaks: [SleepRecord]
    ) -> Int? {
        let averageNap = average(dayNaps.map { $0.totalMinutes(breaks: breaks) })
        guard let averageNap else { return nil }
        var longBedtimes: [Int] = []
        var regularBedtimes: [Int] = []

        for night in nightSleeps {
            let naps = dayNaps.filter { calendar.isDate($0.date, inSameDayAs: night.date) }
            guard !naps.isEmpty else { continue }
            let total = naps.map { $0.totalMinutes(breaks: breaks) }.reduce(0, +)
            let bedtime = calendar.component(.hour, from: night.date) * 60
                + calendar.component(.minute, from: night.date)
            if total > averageNap + 30 {
                longBedtimes.append(bedtime)
            } else {
                regularBedtimes.append(bedtime)
            }
        }
        guard let longAverage = average(longBedtimes),
              let regularAverage = average(regularBedtimes) else { return nil }
        return max(0, longAverage - regularAverage)
    }

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

    private func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private func clockHour(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
}
