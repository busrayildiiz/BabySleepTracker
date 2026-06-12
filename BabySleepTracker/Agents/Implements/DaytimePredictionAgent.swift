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
    case ageBaseline      // 0–13 gün: yaş tablosundan
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

           let profile    = profileProvider.profile(forAgeMonths: ageMonths)
           let breaks     = todayRecords.filter { $0.kind == .break }
           let todayNaps  = todayRecords
               .filter { $0.kind == .dayNap }
               .sorted { $0.date < $1.date }

           // 1. Anchor — tahminın başlangıç noktası
           let anchor = predictionAnchor(
               todayNaps:   todayNaps,
               wakeRecords: wakeRecords,
               now:         now
           )

           // 2. Wake window — blend oranına göre hesapla
           let wakeWindow = blendedWakeWindow(
               profile:      profile,
               pattern:      pattern,
               trackedDays:  trackedDays
           )

           // 3. Tahmin zamanı
           let nextNapTime = anchor.time.addingMinutes(wakeWindow)

           // 4. Pencere yarıçapı — mod'a göre değişir
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
                      mode:          mode,
                      trackedDays:   trackedDays,
                      hasWakeTime:   anchor.hasTodayWakeTime,
                      hasPattern:    pattern != nil
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
            wakeRecords: [DailyWakeRecord],
            now:         Date
        ) -> (time: Date, hasTodayWakeTime: Bool) {

            // Son napın bitiş saati en güvenilir anchor
            if let lastNap = todayNaps.last {
                let end = lastNap.date.addingMinutes(lastNap.duration)
                return (end, true)
            }

            // Wake record varsa onu kullan
            if let wake = wakeRecords
                .filter({ calendar.isDate($0.day, inSameDayAs: now) })
                .max(by: { $0.wakeTime < $1.wakeTime }) {
                return (wake.wakeTime, true)
            }

            // Fallback: sabah 07:00
            let fallback = calendar.date(
                bySettingHour: 7, minute: 0, second: 0, of: now
            ) ?? now
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
            // 14 günde tam personalization, önce kademeli blend
            let weight  = min(1.0, Double(trackedDays) / 14.0)
            let blended = Double(baselineCenter) * (1 - weight) + Double(observed) * weight

            // Makul sınırlar içinde tut
            let minWW = profile.wakeWindowRange.lowerBound - 30
            let maxWW = profile.wakeWindowRange.upperBound + 45
            return max(minWW, min(maxWW, Int(blended.rounded())))
        }

        // MARK: - Expected Nap Duration

        private func expectedNapDuration(
            profile:  AgeBasedSleepProfile,
            pattern:  BabyPattern?,
            napIndex: Int          // bugün kaçıncı nap? (0-indexed)
        ) -> Int {

            // Kişisel ortalama varsa onu kullan
            if let avg = pattern?.averageNapDurationMinutes {
                // Gün içinde sonraki naplar genelde biraz daha kısa
                let adjustment = napIndex > 0 ? -10 : 0
                return max(30, avg + adjustment)
            }

            // Yoksa profil max'ının %75'ini varsayılan al
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
            case .ageBaseline:  return 20   // ±20 dk
            case .blended:      return 15   // ±15 dk
            case .personalized: return 10   // ±10 dk
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

            // Anchor açıklaması
            if anchor.hasTodayWakeTime {
                parts.append("Bugünün uyanma/son nap bitiş saatinden hesaplandı.")
            } else {
                parts.append("Uyanma saati girilmedi — 07:00 varsayıldı. Eklemen doğruluğu artırır.")
            }

            // Wake window açıklaması
            switch mode {
            case .ageBaseline:
                parts.append("\(ageMonths) aylık için yaş baseline'ı kullanıldı (\(wakeWindow) dk).")
            case .blended:
                parts.append("Yaş baseline + \(trackedDays) günlük veri harmanlandı (\(wakeWindow) dk).")
            case .personalized:
                parts.append("Bebeğin kendi örüntüsünden kişiselleştirildi (\(wakeWindow) dk).")
            }

            // Kalan gün
            if trackedDays < 14 {
                let remaining = 14 - trackedDays
                parts.append("\(remaining) gün daha takip edince tahminler kişiselleşecek.")
            }

            return parts
        }
}

// MARK: - Date Extension

private extension Date {
    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
}
