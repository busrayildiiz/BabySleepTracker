import SwiftUI

struct InsightsView: View {
    private enum CoachTab: String, CaseIterable {
        case overview = "Overview"
        case predictions = "Predictions"

        var icon: String {
            self == .overview ? "sparkles" : "chart.line.uptrend.xyaxis"
        }
    }

    @StateObject private var orchestrator = SleepCoachOrchestrator.shared
    @State private var selectedTab: CoachTab = .overview
    @AppStorage("babyName") private var babyName: String = "Baby"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    tabPicker

                    if selectedTab == .overview {
                        predictionCard
                        alertsCard
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
            .onAppear {
                orchestrator.updateAllMetrics()
            }
            .onReceive(NotificationCenter.default.publisher(for: .sleepRecordsDidChange)) { _ in
                orchestrator.updateAllMetrics()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dailyWakeRecordsDidChange)) { _ in
                orchestrator.updateAllMetrics()
            }
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
                phaseBadge
            }

            if let napPrediction = orchestrator.napPrediction {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 10) {
                            iconCircle("sun.max.fill", color: CoachColor.sun, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recommended nap time")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(CoachColor.ink)
                                Text(timeFormatter(napPrediction.nextNapTime))
                                    .font(.system(size: 27, weight: .bold, design: .rounded))
                                    .foregroundStyle(CoachColor.purpleDeep)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }

                        Text("\(napPrediction.confidence)% Confidence")
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
                            Text("\(timeFormatter(napPrediction.windowStart)) - \(timeFormatter(napPrediction.windowEnd))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(CoachColor.purpleDeep)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why this time?")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CoachColor.ink)

                        ForEach(napPrediction.reasoning, id: \.self) { reason in
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
            } else {
                Text("Not enough data to predict. Keep logging sleep and wake times.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CoachColor.muted)
            }
        }
        .padding(15)
        .background(cardBackground)
        .overlay(cardStroke(cornerRadius: 16))
    }

    private var alertsCard: some View {
        Group {
            if let insights = orchestrator.insights, !insights.alerts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("ALERTS", systemImage: "exclamationmark.circle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CoachColor.purple)

                    ForEach(Array(insights.alerts.enumerated()), id: \.element.message) { index, alert in
                        alertRow(alert)
                        if index < insights.alerts.count - 1 {
                            Divider()
                                .overlay(CoachColor.stroke)
                        }
                    }
                }
                .padding(15)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))
            }
        }
    }

    private func alertRow(_ alert: SleepAlert) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: alertIcon(alert.severity))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(alertColor(alert.severity))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CoachColor.ink)
                    
                    if let actionTitle = alert.actionTitle {
                        Button(actionTitle) {
                            // Action handler
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(alertColor(alert.severity))
                        )
                    }
                }
            }
        }
    }

    private var insightsCard: some View {
        Group {
            if let insights = orchestrator.insights {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("\(displayedBabyName.uppercased())'S SLEEP INSIGHTS")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CoachColor.purple)
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        if let weeklyPattern = insights.weeklyPattern {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weekly Pattern")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(CoachColor.ink)
                                Text(weeklyPattern)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CoachColor.muted)
                            }
                            Divider()
                                .overlay(CoachColor.stroke)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Progress")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(CoachColor.ink)
                            Text(insights.progressMessage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(CoachColor.muted)
                        }
                    }
                }
                .padding(15)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))
            }
        }
    }

    private var coachTipCard: some View {
        Group {
            if let insights = orchestrator.insights {
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
                        Text(insights.headline)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CoachColor.ink)
                        Text(insights.coachTip)
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
        }
    }

    private var predictionDetails: some View {
        VStack(spacing: 14) {
            if let report = orchestrator.phaseReport {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Prediction Phase")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(CoachColor.ink)
                            Text(report.phase.description)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CoachColor.muted)
                        }
                        Spacer()
                        phaseBadge
                    }

                    ProgressView(value: min(Double(report.daysUntilPersonalized == 0 ? 14 : 14 - report.daysUntilPersonalized), 14), total: 14)
                        .tint(CoachColor.purpleDeep)

                    HStack {
                        Text("\(14 - report.daysUntilPersonalized) tracked days")
                        Spacer()
                        Text(report.phase == .personalized ? "Personalized" : "\(report.daysUntilPersonalized) days")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CoachColor.muted)
                }
                .padding(15)
                .background(cardBackground)
                .overlay(cardStroke(cornerRadius: 16))
            }

            if let napPrediction = orchestrator.napPrediction {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nap Prediction Details")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CoachColor.ink)
                    
                    ForEach(Array(napPrediction.reasoning.enumerated()), id: \.offset) { index, reason in
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
            }
        }
    }

    private var displayedBabyName: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Baby" : trimmed
    }

    private var phaseBadge: some View {
        Group {
            if let phase = orchestrator.phaseReport?.phase {
                Text(phaseLabel(phase))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(phaseColor(phase))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(phaseColor(phase).opacity(0.10))
                    )
            }
        }
    }

    private func phaseLabel(_ phase: CoachPhase) -> String {
        switch phase {
        case .tooYoung:
            return "TOO YOUNG"
        case .baseline:
            return "BASELINE"
        case .learning(let day):
            return "LEARNING \(min(day, 14))/14"
        case .personalized:
            return "PERSONALIZED"
        }
    }

    private func phaseColor(_ phase: CoachPhase) -> Color {
        switch phase {
        case .tooYoung, .baseline:
            return CoachColor.muted
        case .learning:
            return CoachColor.purple
        case .personalized:
            return CoachColor.green
        }
    }

    private func alertIcon(_ severity: AlertSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }

    private func alertColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .info:
            return CoachColor.purple
        case .warning:
            return Color.orange
        case .critical:
            return Color.red
        }
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

    private func timeFormatter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
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
