//
//  NightPredictionAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 13.06.2026.
//

import Foundation

// MARK: - Night Prediction

struct NightPredictionAgent {
    let optimalBedtimeStart:      Date    // overtired olmadan en erken yatış
    let optimalBedtimeEnd:        Date    // bu saatten geç → overtired riski
    let overtiredRiskTime:        Date    // kesinlikle bu saatten önce yatır
    let expectedNightSleepMinutes: Int
    let lastNapCutoffTime:        Date    // bu saatten sonra nap önerilmez
    let daytimeSleepStatus:       DailySleepStatus
    let confidence:               Int     // 0–94
    let reasoning:                [String]
}

// MARK: - Protocol

protocol NightPredictionAgentProtocol {
    func predictBedtime(
        pattern:          BabyPattern?,
        todayRecords:     [SleepRecord],
        wakeRecords:      [DailyWakeRecord],
        ageMonths:        Int,
        trackedDays:      Int,
        now:              Date
    ) -> NightPredictionAgent
}

// MARK: - DefaultNightPredictionAgent

final class DefaultNightPredictionAgent: NightPredictionAgentProtocol {

    private let calendar:            Calendar
    private let profileProvider:     AgeBasedSleepProfileProviding
    private let overtiredCalculator: OvertiredCalculator

    init(
        profileProvider:     AgeBasedSleepProfileProviding = DefaultAgeBasedSleepProfileProvider(),
        overtiredCalculator: OvertiredCalculator = OvertiredCalculator(),
        calendar:            Calendar = .current
    ) {
        self.profileProvider     = profileProvider
        self.overtiredCalculator = overtiredCalculator
        self.calendar            = calendar
    }

    // MARK: - Predict Bedtime

    func predictBedtime(
        pattern:      BabyPattern?,
        todayRecords: [SleepRecord],
        wakeRecords:  [DailyWakeRecord],
        ageMonths:    Int,
        trackedDays:  Int,
        now:          Date
    ) -> NightPredictionAgent {

        let profile = profileProvider.profile(forAgeMonths: ageMonths)
        let breaks  = todayRecords.filter { $0.kind == .break }
        let dayNaps = todayRecords
            .filter { $0.kind == .dayNap }
            .sorted { $0.date < $1.date }

        // 1. Toplam gündüz uykusu
        let totalDaytime = dayNaps
            .map { $0.totalMinutes(breaks: breaks) }
            .reduce(0, +)

        // 2. Son nap bitiş saati — bedtime hesabının anchor'ı
        let lastNapEnd: Date? = dayNaps.last.map { nap in
            Calendar.current.date(byAdding: .minute, value: nap.duration, to: nap.date) ?? nap.date
        }

        // 3. Bedtime window hesabı
        let bedtimeWindow: BedtimeWindow

        if let lastNapEnd {
            bedtimeWindow = overtiredCalculator.bedtimeWindow(
                lastNapEndTime:            lastNapEnd,
                totalDaytimeSleepMinutes:  totalDaytime,
                ageMonths:                 ageMonths,
                now:                       now
            )
        } else {
            // Bugün hiç nap yok — wake record'dan hesapla
            bedtimeWindow = fallbackBedtimeWindow(
                wakeRecords:  wakeRecords,
                profile:      profile,
                ageMonths:    ageMonths,
                now:          now
            )
        }

        // 4. Son nap cutoff saati
        let cutoff = overtiredCalculator.lastNapCutoffTime(
            ageMonths: ageMonths,
            on:        now
        )

        // 5. Beklenen gece uykusu süresi
        let expectedNight = expectedNightSleep(
            profile: profile,
            pattern: pattern
        )

        // 6. Günlük uyku durumu
        let sleepStatus = overtiredCalculator.dailySleepStatus(
            totalMinutes: totalDaytime,
            ageMonths:    ageMonths
        )

        // 7. Güven skoru
        let confidence = calculateConfidence(
            trackedDays:   trackedDays,
            hasLastNap:    lastNapEnd != nil,
            hasWakeRecord: todayWakeRecord(wakeRecords: wakeRecords, now: now) != nil,
            hasPattern:    pattern != nil
        )

        // 8. Gerekçeler
        let reasoning = buildReasoning(
            profile:       profile,
            lastNapEnd:    lastNapEnd,
            totalDaytime:  totalDaytime,
            bedtime:       bedtimeWindow.ideal,
            ageMonths:     ageMonths,
            sleepStatus:   sleepStatus
        )

        return NightPredictionAgent(
            optimalBedtimeStart:       bedtimeWindow.earliest,
            optimalBedtimeEnd:         bedtimeWindow.latest,
            overtiredRiskTime:         bedtimeWindow.overtiredRisk,
            expectedNightSleepMinutes: expectedNight,
            lastNapCutoffTime:         cutoff,
            daytimeSleepStatus:        sleepStatus,
            confidence:                confidence,
            reasoning:                 reasoning
        )
    }

    // MARK: - Fallback Bedtime (nap yok)

    private func fallbackBedtimeWindow(
        wakeRecords: [DailyWakeRecord],
        profile:     AgeBasedSleepProfile,
        ageMonths:   Int,
        now:         Date
    ) -> BedtimeWindow {

        // Wake record varsa ondan hesapla
        if let wake = todayWakeRecord(wakeRecords: wakeRecords, now: now) {
            return overtiredCalculator.bedtimeWindow(
                lastNapEndTime:           wake.wakeTime,
                totalDaytimeSleepMinutes: 0,
                ageMonths:                ageMonths,
                now:                      now
            )
        }

        // Hiç veri yok — kullanıcının kaydettiği typical bedtime'ı kullan
        // Settings'te ayarlanmadıysa profile'dan yaşa göre default'a düş
        let today = calendar.startOfDay(for: now)

        let hasUserBedtime = UserDefaults.standard.object(forKey: "typicalBedHour") != nil
        let idealBedtime: Date

        if hasUserBedtime {
            let bedHour   = UserDefaults.standard.double(forKey: "typicalBedHour")
            let bedMinute = UserDefaults.standard.double(forKey: "typicalBedMinute")
            idealBedtime = calendar.date(
                bySettingHour: Int(bedHour),
                minute:        Int(bedMinute),
                second:        0,
                of:            today
            ) ?? now
        } else {
            let bedtimeHour = profile.bedtimeHourRange.lowerBound
            idealBedtime = calendar.date(
                bySettingHour: bedtimeHour + 1,
                minute:        0,
                second:        0,
                of:            today
            ) ?? now
        }

        let reasonText = hasUserBedtime
            ? "No nap recorded — using your saved typical bedtime."
            : "Not enough data — using age-based typical bedtime."

        return BedtimeWindow(
            earliest:      idealBedtime.addingMinutes(-30),
            ideal:         idealBedtime,
            latest:        idealBedtime.addingMinutes(30),
            overtiredRisk: idealBedtime.addingMinutes(50),
            risk:          .healthy,
            reasoning:     reasonText
        )
    }

    // MARK: - Expected Night Sleep

    private func expectedNightSleep(
        profile: AgeBasedSleepProfile,
        pattern: BabyPattern?
    ) -> Int {
        if let avg = pattern?.averageNightSleepMinutes {
            return avg
        }
        return (profile.nightSleepRange.lowerBound + profile.nightSleepRange.upperBound) / 2
    }

    // MARK: - Confidence

    private func calculateConfidence(
        trackedDays:   Int,
        hasLastNap:    Bool,
        hasWakeRecord: Bool,
        hasPattern:    Bool
    ) -> Int {
        var score = 40 + min(trackedDays, 14) * 2
        if hasLastNap    { score += 10 }
        if hasWakeRecord { score += 6  }
        if hasPattern    { score += 5  }
        return min(score, 94)
    }

    // MARK: - Reasoning

    private func buildReasoning(
        profile:      AgeBasedSleepProfile,
        lastNapEnd:   Date?,
        totalDaytime: Int,
        bedtime:      Date,
        ageMonths:    Int,
        sleepStatus:  DailySleepStatus
    ) -> [String] {

        let formatter        = DateFormatter()
        formatter.locale     = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"

        var parts = [String]()

        if let napEnd = lastNapEnd {
            parts.append("Last nap ended at \(formatter.string(from: napEnd)).")
        } else {
            parts.append("No nap recorded today — used age-based fixed window.")
        }

        let ewwCenter = (profile.eveningWakeWindow.lowerBound + profile.eveningWakeWindow.upperBound) / 2
        parts.append("Evening wake window for \(ageMonths)-month-old is ~\(ewwCenter) min.")

        switch sleepStatus {
        case .below(let deficit):
            parts.append("Daytime sleep is \(TimeFormat.minutes(deficit)) short — bedtime moved earlier.")
        case .above(let excess):
            parts.append("Daytime sleep is \(TimeFormat.minutes(excess)) over — bedtime may be delayed.")
        case .onTrack:
            parts.append("Daytime sleep is on target.")
        }

        parts.append("Recommended bedtime: \(formatter.string(from: bedtime)).")
        return parts
    }

    // MARK: - Helper

    private func todayWakeRecord(
        wakeRecords: [DailyWakeRecord],
        now:         Date
    ) -> DailyWakeRecord? {
        wakeRecords.first { calendar.isDate($0.day, inSameDayAs: now) }
    }
}
