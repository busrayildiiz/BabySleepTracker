import Foundation

// MARK: - Daytime Prediction

struct DaytimePrediction {
    let nextNapTime:             Date
    let windowStart:             Date
    let windowEnd:               Date
    let expectedDurationMinutes: Int
    let wakeWindowUsed:          Int
    let confidence:              Int      // 0–94
    let mode:                    PredictionMode
    let reasoning:               [String]
}

enum PredictionMode {
    case ageBaseline      // 0–6 gün: yaş tablosundan
    case blended          // 7–13 gün: karma
    case personalized     // 14+ gün: bebeğin kendi verisi
}

// MARK: - Protocol

protocol DaytimePredictionAgentProtocol {
    func predictNextNap(
        pattern:      BabyPattern?,
        todayRecords: [SleepRecord],
        wakeRecords:  [DailyWakeRecord],
        ageMonths:    Int,
        trackedDays:  Int,
        now:          Date
    ) -> DaytimePrediction
}

// MARK: - DefaultDaytimePredictionAgent

final class DefaultDaytimePredictionAgent: DaytimePredictionAgentProtocol {

    private let calendar:        Calendar
    private let profileProvider: AgeBasedSleepProfileProviding

    init(
        profileProvider: AgeBasedSleepProfileProviding = DefaultAgeBasedSleepProfileProvider(),
        calendar:        Calendar = .current
    ) {
        self.profileProvider = profileProvider
        self.calendar        = calendar
    }

    // MARK: - Predict Next Nap

    func predictNextNap(
        pattern:      BabyPattern?,
        todayRecords: [SleepRecord],
        wakeRecords:  [DailyWakeRecord],
        ageMonths:    Int,
        trackedDays:  Int,
        now:          Date
    ) -> DaytimePrediction {

        let profile   = profileProvider.profile(forAgeMonths: ageMonths)
        let breaks    = todayRecords.filter { $0.kind == .break }
        let todayNaps = todayRecords
            .filter { $0.kind == .dayNap }
            .sorted { $0.date < $1.date }

        // 1. Anchor — tahminın başlangıç noktası
        let anchor = predictionAnchor(
            todayNaps:   todayNaps,
            breaks:      breaks,
            wakeRecords: wakeRecords,
            now:         now
        )

        // 2. Wake window — blend oranına göre hesapla
        let wakeWindow = blendedWakeWindow(
            profile:     profile,
            pattern:     pattern,
            trackedDays: trackedDays
        )

        // 3. Tahmin zamanı
        let nextNapTime = anchor.time.addingMinutes(wakeWindow)

        // 4. Mod ve pencere yarıçapı
        let mode         = predictionMode(trackedDays: trackedDays, pattern: pattern)
        let windowRadius = windowRadius(for: mode)

        let windowStart = nextNapTime.addingMinutes(-windowRadius)
        let windowEnd   = nextNapTime.addingMinutes(windowRadius)

        // 5. Beklenen nap süresi
        let expectedDuration = expectedNapDuration(
            profile:  profile,
            pattern:  pattern,
            napIndex: todayNaps.count
        )

        // 6. Güven skoru
        let confidence = calculateConfidence(
            mode:        mode,
            trackedDays: trackedDays,
            hasWakeTime: anchor.hasTodayWakeTime,
            hasPattern:  pattern != nil
        )

        // 7. Gerekçeler
        let reasoning = buildReasoning(
            mode:        mode,
            anchor:      anchor,
            wakeWindow:  wakeWindow,
            ageMonths:   ageMonths,
            trackedDays: trackedDays
        )

        return DaytimePrediction(
            nextNapTime:             nextNapTime,
            windowStart:             windowStart,
            windowEnd:               windowEnd,
            expectedDurationMinutes: expectedDuration,
            wakeWindowUsed:          wakeWindow,
            confidence:              confidence,
            mode:                    mode,
            reasoning:               reasoning
        )
    }

    // MARK: - Anchor

    private func predictionAnchor(
        todayNaps:   [SleepRecord],
        breaks:      [SleepRecord],
        wakeRecords: [DailyWakeRecord],
        now:         Date
    ) -> (time: Date, hasTodayWakeTime: Bool) {

        // Son napın net bitiş saati (break dahil etkili süre)
        if let lastNap = todayNaps.last {
            let effectiveMinutes = lastNap.totalMinutes(breaks: breaks)
            let end = lastNap.date.addingMinutes(effectiveMinutes)
            return (end, true)
        }

        // Bugünün wake record'u varsa kullan
        if let wake = wakeRecords
            .filter({ calendar.isDate($0.day, inSameDayAs: now) })
            .max(by: { $0.wakeTime < $1.wakeTime }) {
            return (wake.wakeTime, true)
        }

        // Fallback: bugünün 07:00'ı
        // Gece 00:00–07:00 arasındaysak henüz sabah olmadı → 07:00 anchor
        // 07:00 geçtiyse → now anchor (kullanıcı kayıt girmemiş)
        let today    = calendar.startOfDay(for: now)
        let morning7 = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today) ?? now
        let fallback = now >= morning7 ? now : morning7
        return (fallback, false)
    }

    // MARK: - Blended Wake Window

    private func blendedWakeWindow(
        profile:     AgeBasedSleepProfile,
        pattern:     BabyPattern?,
        trackedDays: Int
    ) -> Int {
        let baselineCenter =
            (profile.wakeWindowRange.lowerBound + profile.wakeWindowRange.upperBound) / 2

        guard let observed = pattern?.averageWakeWindowMinutes else {
            return baselineCenter
        }

        let weight  = min(1.0, Double(trackedDays) / 14.0)
        let blended = Double(baselineCenter) * (1 - weight) + Double(observed) * weight

        let minWW = profile.wakeWindowRange.lowerBound - 30
        let maxWW = profile.wakeWindowRange.upperBound + 45
        return max(minWW, min(maxWW, Int(blended.rounded())))
    }

    // MARK: - Expected Nap Duration

    private func expectedNapDuration(
        profile:  AgeBasedSleepProfile,
        pattern:  BabyPattern?,
        napIndex: Int
    ) -> Int {
        if let avg = pattern?.averageNapDurationMinutes {
            let adjustment = napIndex > 0 ? -10 : 0
            return max(30, avg + adjustment)
        }
        return Int(Double(profile.maxSingleNapMinutes) * 0.75)
    }

    // MARK: - Prediction Mode

    private func predictionMode(
        trackedDays: Int,
        pattern:     BabyPattern?
    ) -> PredictionMode {
        switch trackedDays {
        case 0...6:  return .ageBaseline
        case 7...13: return .blended
        default:     return pattern != nil ? .personalized : .blended
        }
    }

    // MARK: - Window Radius

    private func windowRadius(for mode: PredictionMode) -> Int {
        switch mode {
        case .ageBaseline:  return 20
        case .blended:      return 15
        case .personalized: return 10
        }
    }

    // MARK: - Confidence

    private func calculateConfidence(
        mode:        PredictionMode,
        trackedDays: Int,
        hasWakeTime: Bool,
        hasPattern:  Bool
    ) -> Int {
        var score: Int
        switch mode {
        case .ageBaseline:  score = 44 + trackedDays * 2
        case .blended:      score = 58 + (trackedDays - 7) * 2
        case .personalized: score = 76
        }
        if hasWakeTime { score += 8 }
        if hasPattern  { score += 5 }
        return min(score, 94)
    }

    // MARK: - Reasoning

    private func buildReasoning(
        mode:        PredictionMode,
        anchor:      (time: Date, hasTodayWakeTime: Bool),
        wakeWindow:  Int,
        ageMonths:   Int,
        trackedDays: Int
    ) -> [String] {
        var parts = [String]()

        if anchor.hasTodayWakeTime {
            parts.append("Calculated from today's wake-up or last nap end time.")
        } else {
            parts.append("No wake time recorded — defaulted to 7:00 AM. Adding it improves accuracy.")
        }

        switch mode {
        case .ageBaseline:
            parts.append("Using age baseline for \(ageMonths)-month-old (\(wakeWindow) min wake window).")
        case .blended:
            parts.append("Blending age baseline with \(trackedDays) days of tracked data (\(wakeWindow) min).")
        case .personalized:
            parts.append("Personalized from \(babyName())'s own sleep pattern (\(wakeWindow) min).")
        }

        if trackedDays < 14 {
            let remaining = 14 - trackedDays
            parts.append("\(remaining) more tracked day\(remaining == 1 ? "" : "s") until fully personalized.")
        }

        return parts
    }

    private func babyName() -> String {
        let name = UserDefaults.standard.string(forKey: "babyName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Baby" : name
    }
}


