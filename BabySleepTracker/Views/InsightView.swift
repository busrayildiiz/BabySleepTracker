import SwiftUI

struct InsightsView: View {

    private enum CoachTab: String, CaseIterable {
        case overview    = "Overview"
        case predictions = "Predictions"

        var icon: String {
            self == .overview ? "sparkles" : "chart.line.uptrend.xyaxis"
        }
    }

    @State private var selectedTab: CoachTab = .overview
    @StateObject private var orchestrator = SleepCoachOrchestrator.shared
    @AppStorage("babyName") private var babyName: String = "Baby"

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    tabPicker

                    if selectedTab == .overview {
                        predictionCard
                        todayPlanCard
                        insightsCard
                        coachTipCard
                    } else {
                        predictionDetails
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 112)
            }
            .background(CoachColor.background)
            .navigationBarHidden(true)
            .onAppear { refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .sleepRecordsDidChange))      { _ in refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .dailyWakeRecordsDidChange)) { _ in refresh() }
            .environment(\.locale, Locale(identifier: "en_US"))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("AI Coach")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(CoachColor.ink)
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(CoachColor.purple)
                }
                HStack(spacing: 5) {
                    Text("\(displayedBabyName)'s intelligent sleep assistant")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CoachColor.muted)
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CoachColor.muted)
                }
            }
            Spacer(minLength: 8)
            CoachMoonArtwork()
                .frame(width: 92, height: 68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tab Picker

       private var tabPicker: some View {
           HStack(spacing: 4) {
               ForEach(CoachTab.allCases, id: \.self) { tab in
                   Button {
                       withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                   } label: {
                       Label(tab.rawValue, systemImage: tab.icon)
                           .font(.system(size: 12, weight: .semibold))
                           .foregroundStyle(selectedTab == tab ? .white : CoachColor.muted)
                           .frame(maxWidth: .infinity)
                           .padding(.vertical, 9)
                           .background(
                               RoundedRectangle(cornerRadius: 9, style: .continuous)
                                   .fill(selectedTab == tab ? CoachColor.purple : Color.clear)
                           )
                   }
                   .buttonStyle(.plain)
               }
           }
           .padding(4)
           .background(
               RoundedRectangle(cornerRadius: 11, style: .continuous)
                   .fill(Color.white)
                   .shadow(color: CoachColor.ink.opacity(0.04), radius: 10, y: 4)
           )
           .overlay(cardStroke(cornerRadius: 11))
       }
    
    // MARK: - Prediction Card

        private var predictionCard: some View {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("NEXT NAP PREDICTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CoachColor.purple)
                    Spacer()
                    learningBadge
                }

                HStack(alignment: .top, spacing: 14) {

                    // Sol — tahmin saati
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 10) {
                            iconCircle("sun.max.fill", color: CoachColor.sun, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recommended nap time")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(CoachColor.ink)
                                Text(time(orchestrator.snapshot?.daytime.nextNapTime ?? Date()))
                                    .font(.system(size: 27, weight: .bold, design: .rounded))
                                    .foregroundStyle(CoachColor.purpleDeep)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }

                        Text("\(orchestrator.snapshot?.daytime.confidence ?? 0)% Confidence")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(CoachColor.purpleDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(CoachColor.purple.opacity(0.10))
                            )
                        VStack(alignment: .leading, spacing: 3) {
                                               Text("Recommended window")
                                                   .font(.system(size: 10, weight: .medium))
                                                   .foregroundStyle(CoachColor.muted)
                                               Text(windowText)
                                                   .font(.system(size: 13, weight: .bold, design: .rounded))
                                                   .foregroundStyle(CoachColor.purpleDeep)
                                           }
                                       }
                                       .frame(maxWidth: .infinity, alignment: .leading)

                                       // Sağ — gerekçeler
                                       VStack(alignment: .leading, spacing: 8) {
                                           Text("Why this time?")
                                               .font(.system(size: 12, weight: .bold))
                                               .foregroundStyle(CoachColor.ink)

                                           ForEach(orchestrator.snapshot?.daytime.reasoning ?? [], id: \.self) { reason in
                                               HStack(alignment: .top, spacing: 7) {
                                                   Image(systemName: "checkmark.circle.fill")
                                                       .font(.system(size: 12))
                                                       .foregroundStyle(CoachColor.green)
                                                       .padding(.top, 1)
                                                   Text(reason)
                                                       .font(.system(size: 10, weight: .medium))
                                                       .foregroundStyle(CoachColor.muted)
                                                       .fixedSize(horizontal: false, vertical: true)
                                               }
                                           }
                                       }
                                       .frame(maxWidth: .infinity, alignment: .leading)
                                       .padding(11)
                                       .background(
                                           RoundedRectangle(cornerRadius: 10, style: .continuous)
                                               .fill(CoachColor.purple.opacity(0.055))
                                       )
                                   }
                               }
                    .padding(15)
                    .background(cardBackground)
                    .overlay(cardStroke(cornerRadius: 16))
                }

                // MARK: - Learning Badge

                private var learningBadge: some View {
                    let isPersonalized = orchestrator.snapshot?.phase == .personalized
                    return Text(modeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isPersonalized ? CoachColor.green : CoachColor.purpleDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isPersonalized
                                      ? CoachColor.green.opacity(0.10)
                                      : CoachColor.purple.opacity(0.10))
                        )
                }
    private var todayPlanCard: some View {
            VStack(alignment: .leading, spacing: 13) {
                Label("TODAY'S PLAN", systemImage: "calendar")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CoachColor.purple)

                // Bugünün özet timeline'ı
                HStack(spacing: 0) {
                    planItem(
                        icon: "sun.max.fill",
                        color: CoachColor.sun,
                        timeText: "Wake up",
                        title: "Morning",
                        detail: "Day started",
                        isPrediction: false
                    )
                    planItem(
                        icon: "moon.fill",
                        color: CoachColor.purple,
                        timeText: time(orchestrator.snapshot?.daytime.nextNapTime ?? Date()),
                        title: "Next Nap",
                        detail: "Predicted",
                        isPrediction: true
                    )
                    planItem(
                        icon: "moon.stars.fill",
                        color: CoachColor.purpleDeep,
                        timeText: time(orchestrator.snapshot?.night.optimalBedtimeStart ?? Date()),
                        title: "Bedtime",
                        detail: "Optimal",
                        isPrediction: true
                    )
                }
                
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(CoachColor.purple)
                    Text("The plan adjusts as the day goes on. Predictions refresh after every new record.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CoachColor.muted)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CoachColor.purple.opacity(0.055))
                )
            }
            .padding(15)
            .background(cardBackground)
            .overlay(cardStroke(cornerRadius: 16))
        }

        private func planItem(
            icon: String,
            color: Color,
            timeText: String,
            title: String,
            detail: String,
            isPrediction: Bool
        ) -> some View {
            VStack(spacing: 6) {
                iconCircle(icon, color: color, size: 34)
                Text(timeText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isPrediction ? CoachColor.purpleDeep : CoachColor.muted)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CoachColor.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isPrediction ? CoachColor.purpleDeep : CoachColor.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }

        // MARK: - Insights Card

        private var insightsCard: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                    Text("\(displayedBabyName.uppercased())'S SLEEP INSIGHTS")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(CoachColor.purple)
                .padding(.bottom, 8)

                let alerts = orchestrator.snapshot?.insights.alerts ?? []

                if alerts.isEmpty {
                    Text("Keep logging sleep to unlock personalized insights.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CoachColor.muted)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(alerts.enumerated()), id: \.offset) { index, alert in
                        alertRow(alert)
                        if index < alerts.count - 1 {
                            Divider()
                                .overlay(CoachColor.stroke)
                                .padding(.leading, 48)
                        }
                    }
                }
            }
            .padding(15)
            .background(cardBackground)
            .overlay(cardStroke(cornerRadius: 16))
        }

        private func alertRow(_ alert: SleepAlert) -> some View {
            HStack(spacing: 11) {
                iconCircle(
                    alertIcon(alert.severity),
                    color: alertColor(alert.severity),
                    size: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(alertTitle(alert.severity))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CoachColor.ink)
                    Text(alert.message)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CoachColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if let actionTitle = alert.actionTitle {
                    Text(actionTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CoachColor.purpleDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(CoachColor.purple.opacity(0.10))
                        )
                }
            }
            .padding(.vertical, 9)
        }

        // MARK: - Coach Tip Card

        private var coachTipCard: some View {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CoachColor.purple.opacity(0.10))
                        .frame(width: 56, height: 56)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(CoachColor.purpleDeep)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("AI COACH TIP", systemImage: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(CoachColor.purple)
                    Text(tipTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CoachColor.ink)
                    Text(orchestrator.snapshot?.insights.coachTip ?? "Keep logging to unlock personalized tips.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CoachColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardStroke(cornerRadius: 16))
        }

        // MARK: - Prediction Details

        private var predictionDetails: some View {
            VStack(spacing: 14) {

                // Phase durumu
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Prediction status")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(CoachColor.ink)
                            Text(modeDescription)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CoachColor.muted)
                        }
                        Spacer()
                        learningBadge
                    }

                    let trackedDays = orchestrator.snapshot?.readiness.daysUntilPersonalized == 0
                        ? 14
                        : 14 - (orchestrator.snapshot?.readiness.daysUntilPersonalized ?? 14)

                    ProgressView(value: min(Double(trackedDays), 14), total: 14)
                        .tint(CoachColor.purpleDeep)

                    HStack {
                        Text("\(min(trackedDays, 14)) tracked days")
                        Spacer()
                        Text(orchestrator.snapshot?.phase == .personalized ? "Personalized" : "14 days needed")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CoachColor.muted)
                }
                .padding(15)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))

                // Gerekçeler
                VStack(alignment: .leading, spacing: 12) {
                    Text("How this prediction was formed")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CoachColor.ink)

                    ForEach(
                        Array((orchestrator.snapshot?.daytime.reasoning ?? []).enumerated()),
                        id: \.offset
                    ) { index, reason in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(CoachColor.purpleDeep))
                            Text(reason)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CoachColor.ink)
                        }
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))

                // Night prediction
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tonight's Bedtime Window", systemImage: "moon.stars.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CoachColor.purpleDeep)

                    if let night = orchestrator.snapshot?.night {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Earliest")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CoachColor.muted)
                                Text(time(night.optimalBedtimeStart))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(CoachColor.green)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Latest")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CoachColor.muted)
                                Text(time(night.optimalBedtimeEnd))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(CoachColor.purpleDeep)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Overtired Risk")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CoachColor.muted)
                                Text(time(night.overtiredRiskTime))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red)
                            }
                        }

                        ForEach(night.reasoning, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(CoachColor.purpleDeep)
                                    .padding(.top, 2)
                                Text(reason)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CoachColor.muted)
                            }
                        }
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))

                // Health guardrail
                VStack(alignment: .leading, spacing: 5) {
                    Label("Health guardrail", systemImage: "shield.checkered")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CoachColor.green)
                    Text(healthGuardrailText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CoachColor.muted)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))
            }
        }

        // MARK: - Computed Properties

        private var displayedBabyName: String {
            let trimmed = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? (orchestrator.snapshot?.babyName ?? "Baby") : trimmed
        }

        private var modeLabel: String {
            guard let phase = orchestrator.snapshot?.phase else { return "BASELINE" }
            switch phase {
            case .tooYoung:          return "TOO YOUNG"
            case .baseline:          return "AGE BASELINE"
            case .learning(let day): return "LEARNING \(min(day, 14))/14"
            case .personalized:      return "PERSONALIZED"
            }
        }

        private var modeDescription: String {
            guard let phase = orchestrator.snapshot?.phase else {
                return "Start logging sleep to begin."
            }
            switch phase {
            case .tooYoung:
                return "Predictions activate at 4 months."
            case .baseline:
                return "Using age baseline until sleep and wake records are added."
            case .learning:
                return "Blending age baseline with \(displayedBabyName)'s observed rhythm."
            case .personalized:
                return "Predictions now prioritize \(displayedBabyName)'s own sleep rhythm."
            }
        }

        private var tipTitle: String {
            guard let readiness = orchestrator.snapshot?.readiness else {
                return "Start with today's wake-up time"
            }
            return readiness.missingSignals.contains(.wakeTime)
                ? "Start with today's wake-up time"
                : "Follow the window, then follow the baby"
        }

        private var windowText: String {
            guard let daytime = orchestrator.snapshot?.daytime else { return "–" }
            return "\(time(daytime.windowStart)) – \(time(daytime.windowEnd))"
        }

        private var healthGuardrailText: String {
            guard let ageMonths = orchestrator.snapshot?.ageMonths else {
                return "Log sleep to see health guardrail info."
            }
            if ageMonths < 4 {
                return "AAP guidance does not set a fixed sleep target before 4 months."
            }
            return "AAP-endorsed guidance checks total 24h sleep. The nap time comes from \(displayedBabyName)'s own data."
        }

        // MARK: - Alert Helpers

        private func alertIcon(_ severity: AlertSeverity) -> String {
            switch severity {
            case .info:     return "info.circle.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.circle.fill"
            }
        }

        private func alertColor(_ severity: AlertSeverity) -> Color {
            switch severity {
            case .info:     return CoachColor.purple
            case .warning:  return CoachColor.sun
            case .critical: return .red
            }
        }

        private func alertTitle(_ severity: AlertSeverity) -> String {
            switch severity {
            case .info:     return "Info"
            case .warning:  return "Heads up"
            case .critical: return "Action needed"
            }
        }

        // MARK: - Shared UI

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: CoachColor.ink.opacity(0.035), radius: 12, y: 6)
        }

        private func cardStroke(cornerRadius: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CoachColor.stroke, lineWidth: 1)
        }

        private func iconCircle(_ icon: String, color: Color, size: CGFloat) -> some View {
            ZStack {
                Circle()
                    .fill(color.opacity(0.11))
                    .frame(width: size, height: size)
                Image(systemName: icon)
                    .font(.system(size: size * 0.43, weight: .semibold))
                    .foregroundStyle(color)
            }
        }

        private func time(_ date: Date) -> String {
            let f = DateFormatter()
            f.locale     = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "h:mm a"
            return f.string(from: date)
        }

        private func refresh() {
            orchestrator.generate()
        }
    }

    // MARK: - Moon Artwork

    private struct CoachMoonArtwork: View {
        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CoachColor.purple.opacity(0.55))
                        .position(x: w * 0.13, y: h * 0.32)
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(CoachColor.sun.opacity(0.85))
                        .position(x: w * 0.86, y: h * 0.33)
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: w * 0.68, height: w * 0.68)
                        .shadow(color: CoachColor.purple.opacity(0.14), radius: 13)
                        .position(x: w * 0.56, y: h * 0.50)
                    Circle()
                        .fill(CoachColor.background)
                        .frame(width: w * 0.56, height: w * 0.56)
                        .position(x: w * 0.70, y: h * 0.36)
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.39, y: h * 0.57))
                        path.addQuadCurve(
                            to: CGPoint(x: w * 0.61, y: h * 0.57),
                            control: CGPoint(x: w * 0.50, y: h * 0.69)
                        )
                    }
                    .stroke(CoachColor.purpleDeep, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
                }
            }
        }
    }

    // MARK: - Colors

    private enum CoachColor {
        static let background = Color(red: 0.985, green: 0.98,  blue: 1.0)
        static let ink        = Color(red: 0.035, green: 0.04,  blue: 0.22)
        static let muted      = Color(red: 0.38,  green: 0.39,  blue: 0.52)
        static let purple     = Color(red: 0.55,  green: 0.45,  blue: 0.96)
        static let purpleDeep = Color(red: 0.38,  green: 0.27,  blue: 0.88)
        static let sun        = Color(red: 1.0,   green: 0.68,  blue: 0.12)
        static let green      = Color(red: 0.12,  green: 0.64,  blue: 0.42)
        static let pink       = Color(red: 0.88,  green: 0.34,  blue: 0.61)
        static let stroke     = Color(red: 0.91,  green: 0.90,  blue: 0.95)
    }

