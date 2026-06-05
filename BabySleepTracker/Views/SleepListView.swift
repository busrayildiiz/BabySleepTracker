import SwiftUI
import Charts

struct SleepListView: View {

    // MARK: - Sheet routing
    struct SelectedDay: Identifiable {
        let id = UUID()
        let day: Date
    }

    enum ActiveSheet: Identifiable {
        case addSleep
        case addBreak(napID: UUID, date: Date)
        case dayDetail(SelectedDay)

        var id: String {
            switch self {
            case .addSleep: return "addSleep"
            case .addBreak(let id, _): return "addBreak-\(id)"
            case .dayDetail(let d): return "dayDetail-\(d.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil
    @State private var records: [SleepRecord] = []
    @State private var animateChart = false

    // MARK: - Persistence

    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: "sleepRecords")
        }
    }

    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: "sleepRecords"),
           let decoded = try? JSONDecoder().decode([SleepRecord].self, from: data) {
            records = decoded
        }
    }

    // MARK: - Derived data

    private var todayRecords: [SleepRecord] {
        records.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayNaps: [SleepRecord] {
        todayRecords.filter { $0.kind != .break }.sorted { $0.date < $1.date }
    }

    private var todayBreaks: [SleepRecord] {
        todayRecords.filter { $0.kind == .break }
    }

    private var todayTotal: Int {
        totalMinutes(for: todayRecords)
    }

    private var yesterdayTotal: Int {
        let cal = Calendar.current
        let yesterday = records.filter { cal.isDateInYesterday($0.date) }
        return totalMinutes(for: yesterday)
    }

    private var vsYesterday: Int { todayTotal - yesterdayTotal }

    private var last7DaysAverage: Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let lastWeek = records.filter { $0.date >= sevenDaysAgo }
        guard !lastWeek.isEmpty else { return 0 }
        let grouped = Dictionary(grouping: lastWeek) { calendar.startOfDay(for: $0.date) }
        return grouped.values.map { totalMinutes(for: Array($0)) }.reduce(0, +) / 7
    }

    private var consistencyLabel: String {
        let cal = Calendar.current
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        let activeDays = days.filter { day in
            records.contains { cal.isDate($0.date, inSameDayAs: day) && $0.kind != .break }
        }.count
        switch activeDays {
        case 6...7: return "Excellent"
        case 4...5: return "Good"
        case 2...3: return "Fair"
        default: return "Low"
        }
    }

    struct DailySleep: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let totalMinutes: Int
    }

    private var last7DaysData: [DailySleep] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return DailySleep(
                date: day,
                label: formatter.string(from: day).capitalized,
                totalMinutes: totalMinutes(for: dayRecords)
            )
        }
    }

    private func totalMinutes(for items: [SleepRecord]) -> Int {
        let naps = items.filter { $0.kind != .break }
        let breaks = items.filter { $0.kind == .break }
        return naps.reduce(0) { $0 + $1.totalMinutes(breaks: breaks) }
    }

    private var chartMax: Int {
        let maxVal = last7DaysData.map { $0.totalMinutes }.max() ?? 60
        return max(120, Int(ceil(Double(maxVal) / 60.0)) * 60)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    heroCard
                    statsRow
                    todaySessionsSection
                    addSessionButton
                    insightCard
                    weekChartCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear { loadRecords() }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addSleep:
                AddRecordView(
                    defaultDate: Date(),
                    vm: AddRecordViewModel(),
                    onSave: { newRecord in
                        records.append(newRecord)
                        saveRecords()
                    }
                )
            case .addBreak(let napID, let date):
                AddBreakView(
                    defaultDate: date,
                    targetNapID: napID,
                    onSave: { newBreak in
                        records.append(newBreak)
                        saveRecords()
                    }
                )
            case .dayDetail(let selected):
                let dayRecords = records
                    .filter { Calendar.current.isDate($0.date, inSameDayAs: selected.day) }
                    .sorted { $0.date < $1.date }
                DayDetailView(
                    day: selected.day,
                    records: dayRecords,
                    onDelete: { idsToDelete in
                        records.removeAll { idsToDelete.contains($0.id) }
                        saveRecords()
                    },
                    onAddSleep: { _ in activeSheet = .addSleep },
                    onBreakSaved: { newBreak in
                        records.append(newBreak)
                        saveRecords()
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(greeting), Büşra")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("💜")
                }
                Text("Here's how Umay slept today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text("👶")
                    .font(.system(size: 26))
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.12), Color.purple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative moon
            Text("🌙")
                .font(.system(size: 80))
                .opacity(0.25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                // Badge
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.indigo)
                    Text("Great nap!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundStyle(.indigo.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.indigo.opacity(0.12))
                )

                Text("Umay slept")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(TimeFormat.minutes(todayTotal))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)

                Text("Net sleep time")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // vs yesterday
                if yesterdayTotal > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: vsYesterday >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(vsYesterday >= 0 ? .green : .red)
                        Text("\(vsYesterday >= 0 ? "+" : "")\(TimeFormat.minutes(abs(vsYesterday))) vs yesterday")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(vsYesterday >= 0 ? .green : .red)
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "sun.max.fill",
                iconColor: .orange,
                iconBg: Color.orange.opacity(0.15),
                title: "Today",
                value: TimeFormat.minutes(todayTotal),
                subtitle: "Net Sleep"
            )

            Divider().frame(height: 50)

            statCell(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .indigo,
                iconBg: Color.indigo.opacity(0.12),
                title: "7-Day Avg",
                value: TimeFormat.minutes(last7DaysAverage),
                subtitle: "Net Sleep"
            )

            Divider().frame(height: 50)

            statCell(
                icon: "star",
                iconColor: .green,
                iconBg: Color.green.opacity(0.12),
                title: "Consistency",
                value: consistencyLabel,
                subtitle: "This Week"
            )
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func statCell(icon: String, iconColor: Color, iconBg: Color,
                          title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Today's Sessions

    private var todaySessionsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Today's Sessions")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    activeSheet = .dayDetail(SelectedDay(day: Date()))
                } label: {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .padding(.bottom, 12)

            if todayNaps.isEmpty {
                Text("No sessions today. Tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(todayNaps) { nap in
                        let napBreaks = todayBreaks.filter { $0.parentNapID == nap.id }
                        let net = nap.totalMinutes(breaks: todayBreaks)
                        let napEnd = nap.date.addingTimeInterval(TimeInterval(nap.duration * 60))

                        VStack(spacing: 0) {
                            // Nap row
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: nap.kind.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(nap.kind == .nightSleep ? "Night Sleep" : "Day Nap")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.indigo)
                                    Text("\(TimeFormat.ampm(nap.date)) – \(TimeFormat.ampm(napEnd))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(TimeFormat.minutes(nap.duration))
                                        .font(.subheadline.weight(.bold))
                                    Text("Net Sleep")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            // Wake periods row (break'ler varsa)
                            if !napBreaks.isEmpty {
                                Divider().padding(.leading, 14)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.indigo.opacity(0.10))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.indigo)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Wake Periods")
                                            .font(.subheadline.weight(.medium))
                                        Text("\(napBreaks.count) interruption\(napBreaks.count > 1 ? "s" : "")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        ForEach(napBreaks.prefix(2)) { br in
                                            let end = br.date.addingTimeInterval(TimeInterval(br.duration * 60))
                                            Text("\(TimeFormat.ampm(br.date)) (\(TimeFormat.minutes(br.duration)))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                        }

                        if nap.id != todayNaps.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Add Session Button

    private var addSessionButton: some View {
        Button {
            activeSheet = .addSleep
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("Add Sleep Session")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.indigo)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                Color.indigo.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Insight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)

                let msg = insightMessage
                Text(msg.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(msg.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini trend line decoration
            Image(systemName: vsYesterday >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(Color.indigo.opacity(0.2))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.indigo.opacity(0.06))
        )
    }

    private var insightMessage: (title: String, subtitle: String) {
        guard yesterdayTotal > 0, todayTotal > 0 else {
            return ("Keep tracking!", "Add sleep sessions to see insights.")
        }
        let pct = Int(Double(vsYesterday) / Double(max(1, yesterdayTotal)) * 100)
        if vsYesterday > 0 {
            return ("Umay's naps are getting longer!", "She slept \(pct)% more today compared to yesterday.")
        } else if vsYesterday < 0 {
            return ("Slightly less sleep today.", "She slept \(abs(pct))% less than yesterday.")
        } else {
            return ("Consistent sleep today!", "Same duration as yesterday.")
        }
    }

    // MARK: - Week Chart Card

    private var weekChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Text("Total Sleep")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }

            Chart(last7DaysData) { item in
                let isToday = Calendar.current.isDateInToday(item.date)
                BarMark(
                    x: .value("Day", item.label),
                    y: .value("Minutes", animateChart ? item.totalMinutes : 0)
                )
                .cornerRadius(6)
                .foregroundStyle(
                    isToday
                    ? AnyShapeStyle(Color.indigo)
                    : AnyShapeStyle(Color.indigo.opacity(0.20))
                )
                .annotation(position: .bottom) {
                    VStack(spacing: 2) {
                        if item.totalMinutes > 0 {
                            Text(TimeFormat.minutes(item.totalMinutes))
                                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? .indigo : .secondary)
                        } else {
                            Text("0m")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                    }
                }
            }
            .chartYScale(domain: 0...chartMax)
            .chartYAxis {
                AxisMarks(values: [0, chartMax / 2, chartMax]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.primary.opacity(0.07))
                    AxisValueLabel {
                        if let m = value.as(Int.self) {
                            Text("\(m / 60)h")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 160)
            .onAppear {
                animateChart = false
                withAnimation(.easeOut(duration: 0.7)) { animateChart = true }
            }
            .onChange(of: records.count) { _ in
                animateChart = false
                withAnimation(.easeInOut(duration: 0.6)) { animateChart = true }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
