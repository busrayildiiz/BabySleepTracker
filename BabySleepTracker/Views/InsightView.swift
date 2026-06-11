import SwiftUI

struct InsightsView: View {
    private enum CoachTab: String, CaseIterable {
        case overview = "Overview"
        case predictions = "Predictions"

        var icon: String {
            self == .overview ? "sparkles" : "chart.line.uptrend.xyaxis"
        }
    }

    @State private var selectedTab: CoachTab = .overview
    @State private var snapshot = SleepCoachService.shared.generateSnapshot()
    @AppStorage("babyName") private var babyName: String = "Baby"

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
            .onAppear(perform: refresh)
            .onReceive(NotificationCenter.default.publisher(for: .sleepRecordsDidChange)) { _ in refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .dailyWakeRecordsDidChange)) { _ in refresh() }
            .environment(\.locale, Locale(identifier: "en_US"))
        }
    }

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

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(CoachTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? Color.white : CoachColor.muted)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        iconCircle("sun.max.fill", color: CoachColor.sun, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended nap time")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CoachColor.ink)
                            Text(time(snapshot.prediction.recommendedTime))
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundStyle(CoachColor.purpleDeep)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }

                    Text("\(snapshot.prediction.confidence)% Confidence")
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
                        Text("\(time(snapshot.prediction.windowStart)) - \(time(snapshot.prediction.windowEnd))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(CoachColor.purpleDeep)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Why this time?")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CoachColor.ink)

                    ForEach(snapshot.prediction.reasons, id: \.self) { reason in
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

    private var learningBadge: some View {
        Text(modeLabel)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(snapshot.prediction.mode == .personalized ? CoachColor.green : CoachColor.purpleDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        snapshot.prediction.mode == .personalized
                            ? CoachColor.green.opacity(0.10)
                            : CoachColor.purple.opacity(0.10)
                    )
            )
    }

    private var todayPlanCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("TODAY'S PLAN", systemImage: "calendar")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(CoachColor.purple)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(snapshot.plan.prefix(4).enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 6) {
                        iconCircle(
                            item.icon,
                            color: item.icon.contains("sun") ? CoachColor.sun : CoachColor.purple,
                            size: 34
                        )
                        Text(time(item.time))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(item.isPrediction ? CoachColor.purpleDeep : CoachColor.muted)
                            .lineLimit(1)
                        Text(item.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(CoachColor.ink)
                            .lineLimit(1)
                        Text(item.detail)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(item.isPrediction ? CoachColor.purpleDeep : CoachColor.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        if index < min(snapshot.plan.count, 4) - 1 {
                            Rectangle()
                                .fill(CoachColor.stroke)
                                .frame(height: 1)
                                .offset(x: 12, y: 17)
                        }
                    }
                }
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

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                Text("\(displayedBabyName.uppercased())'S SLEEP INSIGHTS")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(CoachColor.purple)
            .padding(.bottom, 8)

            ForEach(Array(snapshot.insights.enumerated()), id: \.element.id) { index, insight in
                insightRow(insight)
                if index < snapshot.insights.count - 1 {
                    Divider()
                        .overlay(CoachColor.stroke)
                        .padding(.leading, 48)
                }
            }
        }
        .padding(15)
        .background(cardBackground)
        .overlay(cardStroke(cornerRadius: 16))
    }

    private func insightRow(_ insight: SleepCoachInsight) -> some View {
        HStack(spacing: 11) {
            iconCircle(insight.icon, color: toneColor(insight.tone), size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CoachColor.ink)
                Text(insight.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CoachColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Text(insight.value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(toneColor(insight.tone))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(toneColor(insight.tone).opacity(0.08))
                )
        }
        .padding(.vertical, 9)
    }

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
                Text(snapshot.coachTip)
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

    private var predictionDetails: some View {
        VStack(spacing: 14) {
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

                ProgressView(value: min(Double(snapshot.prediction.trackedDays), 14), total: 14)
                    .tint(CoachColor.purpleDeep)

                HStack {
                    Text("\(min(snapshot.prediction.trackedDays, 14)) tracked days")
                    Spacer()
                    Text(snapshot.prediction.mode == .personalized ? "Personalized" : "14 days")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CoachColor.muted)
            }
            .padding(15)
            .background(cardBackground)
            .overlay(cardStroke(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("How this prediction was formed")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CoachColor.ink)
                ForEach(Array(snapshot.prediction.reasons.enumerated()), id: \.offset) { index, reason in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
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

    private var displayedBabyName: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? snapshot.babyName : trimmed
    }

    private var modeLabel: String {
        switch snapshot.prediction.mode {
        case .baseline: return "AGE BASELINE"
        case .learning: return "LEARNING \(min(snapshot.prediction.trackedDays, 14))/14"
        case .personalized: return "PERSONALIZED"
        }
    }

    private var modeDescription: String {
        switch snapshot.prediction.mode {
        case .baseline:
            return "Using the age baseline until sleep and wake records are added."
        case .learning:
            return "Gradually blending the age baseline with \(displayedBabyName)'s observed rhythm."
        case .personalized:
            return "Predictions now prioritize \(displayedBabyName)'s own sleep rhythm."
        }
    }

    private var tipTitle: String {
        snapshot.prediction.hasTodayWakeTime ? "Follow the window, then follow the baby" : "Start with today's wake-up time"
    }

    private var healthGuardrailText: String {
        if snapshot.guideline.minimumDailyMinutes == 0 {
            return "AAP-endorsed guidance does not set a fixed sleep-duration target before 4 months. The nap estimate uses the product baseline and \(displayedBabyName)'s own records."
        }
        return "AAP-endorsed guidance is used to check total sleep over 24 hours. The exact nap time comes from the age baseline and \(displayedBabyName)'s own data."
    }

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

    private func toneColor(_ tone: String) -> Color {
        switch tone {
        case "green": return CoachColor.green
        case "pink": return CoachColor.pink
        default: return CoachColor.purpleDeep
        }
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func refresh() {
        snapshot = SleepCoachService.shared.generateSnapshot()
    }
}

private struct CoachMoonArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CoachColor.purple.opacity(0.55))
                    .position(x: width * 0.13, y: height * 0.32)
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(CoachColor.sun.opacity(0.85))
                    .position(x: width * 0.86, y: height * 0.33)

                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: width * 0.68, height: width * 0.68)
                    .shadow(color: CoachColor.purple.opacity(0.14), radius: 13)
                    .position(x: width * 0.56, y: height * 0.50)

                Circle()
                    .fill(CoachColor.background)
                    .frame(width: width * 0.56, height: width * 0.56)
                    .position(x: width * 0.70, y: height * 0.36)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.39, y: height * 0.57))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.61, y: height * 0.57),
                        control: CGPoint(x: width * 0.50, y: height * 0.69)
                    )
                }
                .stroke(CoachColor.purpleDeep, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
            }
        }
    }
}

private enum CoachColor {
    static let background = Color(red: 0.985, green: 0.98, blue: 1.0)
    static let ink = Color(red: 0.035, green: 0.04, blue: 0.22)
    static let muted = Color(red: 0.38, green: 0.39, blue: 0.52)
    static let purple = Color(red: 0.55, green: 0.45, blue: 0.96)
    static let purpleDeep = Color(red: 0.38, green: 0.27, blue: 0.88)
    static let sun = Color(red: 1.0, green: 0.68, blue: 0.12)
    static let green = Color(red: 0.12, green: 0.64, blue: 0.42)
    static let pink = Color(red: 0.88, green: 0.34, blue: 0.61)
    static let stroke = Color(red: 0.91, green: 0.90, blue: 0.95)
}
