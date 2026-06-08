import SwiftUI
import Charts

struct HistoryView: View {

    @State private var records: [SleepRecord] = []
    @State private var selectedDate: Date = Date()
    @State private var currentWeekOffset: Int = 0
    @State private var animateChart = false
    @AppStorage("babyName") private var babyName: String = "Baby"

    private let calendar = Calendar.current

    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: "sleepRecords"),
           let decoded = try? JSONDecoder().decode([SleepRecord].self, from: data) {
            records = decoded
        }
    }

    // MARK: - Week days

    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Pazartesi başlangıç (1=Sun → offset 2, 2=Mon → offset 1 ...)
        let mondayOffset = (weekday == 1 ? -6 : -(weekday - 2))
        let monday = calendar.date(byAdding: .day, value: mondayOffset + (currentWeekOffset * 7), to: today)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: monday)! }
    }

    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: weekDays[3])
    }

    // MARK: - Selected day data

    private var selectedDayRecords: [SleepRecord] {
        records.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedDayNaps: [SleepRecord] {
        selectedDayRecords.filter { $0.kind != .break }.sorted { $0.date < $1.date }
    }

    private var selectedDayBreaks: [SleepRecord] {
        selectedDayRecords.filter { $0.kind == .break }
    }

    private var selectedDayNetSleep: Int {
        totalMinutes(for: selectedDayRecords)
    }

    private var selectedDayWakePeriods: Int {
        selectedDayBreaks.count
    }

    // MARK: - Yesterday comparison

    private var yesterdayNetSleep: Int {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return 0 }
        let recs = records.filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
        return totalMinutes(for: recs)
    }

    private var vsYesterday: Int { selectedDayNetSleep - yesterdayNetSleep }

    // MARK: - Week chart data

    struct DailySleep: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let minutes: Int
    }

    private var weekChartData: [DailySleep] {
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US")
        dayFormatter.dateFormat = "EEE"
        return weekDays.map { day in
            let recs = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return DailySleep(
                date: day,
                label: dayFormatter.string(from: day),
                minutes: totalMinutes(for: recs)
            )
        }
    }

    private var weekTotal: Int { weekChartData.map { $0.minutes }.reduce(0, +) }

    private var chartMax: Int {
        let maxVal = weekChartData.map { $0.minutes }.max() ?? 60
        return max(120, Int(ceil(Double(maxVal) / 60.0)) * 60)
    }

    // MARK: - Helpers

    private func totalMinutes(for items: [SleepRecord]) -> Int {
        let naps = items.filter { $0.kind != .break }
        let breaks = items.filter { $0.kind == .break }
        return naps.reduce(0) { $0 + $1.totalMinutes(breaks: breaks) }
    }

    private func hasRecords(on day: Date) -> Bool {
        records.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private var selectedDayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private var dayMessage: String {
        if selectedDayNetSleep == 0 { return "No sleep recorded for this day." }
        if selectedDayNetSleep >= 60 * 2 { return "Great nap day! \(babyName) was happy and rested well." }
        return "Short sleep day. Consider adding more nap time."
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Header ─────────────────────────────
                    headerSection

                    // ── Calendar strip ─────────────────────
                    calendarStrip

                    // ── Selected day card ──────────────────
                    selectedDayCard

                    // ── Stats row ──────────────────────────
                    statsRow

                    // ── Today's naps ───────────────────────
                    if !selectedDayNaps.isEmpty {
                        napsSection
                    }

                    // ── Comparison banner ──────────────────
                    if yesterdayNetSleep > 0 || selectedDayNetSleep > 0 {
                        comparisonBanner
                    }

                    // ── Week overview chart ────────────────
                    weekChartCard

                    // ── Tip ────────────────────────────────
                    tipCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear { loadRecords() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(.largeTitle.weight(.bold))
                HStack(spacing: 4) {
                    Text("\(babyName)'s sleep journey")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("✨")
                }
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.indigo)
            }
        }
    }

    // MARK: - Calendar Strip

    private var calendarStrip: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentWeekOffset -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(monthYearTitle)
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentWeekOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
            }

            // Day names
            HStack(spacing: 0) {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { d in
                    Text(d)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day numbers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(day)
                    let hasDot = hasRecords(on: day)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.orange : Color.clear)
                                    .frame(width: 38, height: 38)

                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                                    .foregroundStyle(isSelected ? .white : (isToday ? .orange : .primary))
                            }

                            // Dot — record var mı
                            Circle()
                                .fill(hasDot ? (isSelected ? Color.white.opacity(0.8) : Color.orange) : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - Selected Day Card

    private var selectedDayCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.08), Color.indigo.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("🌙")
                .font(.system(size: 70))
                .opacity(0.20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(selectedDayTitle)
                        .font(.title3.weight(.bold))
                    Image(systemName: "heart")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                }

                Text(dayMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "moon.fill",
                iconColor: .indigo,
                iconBg: Color.indigo.opacity(0.12),
                label: "Net Sleep",
                value: selectedDayNetSleep > 0 ? TimeFormat.minutes(selectedDayNetSleep) : "–"
            )
            Divider().frame(height: 44)
            statCell(
                icon: "sun.max.fill",
                iconColor: .orange,
                iconBg: Color.orange.opacity(0.12),
                label: "Sessions",
                value: selectedDayNaps.isEmpty ? "–" : "\(selectedDayNaps.count) nap\(selectedDayNaps.count > 1 ? "s" : "")"
            )
            Divider().frame(height: 44)
            statCell(
                icon: "heart",
                iconColor: .pink,
                iconBg: Color.pink.opacity(0.10),
                label: "Wake Periods",
                value: selectedDayWakePeriods == 0 ? "–" : "\(selectedDayWakePeriods) times"
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
                          label: String, value: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(iconColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Naps Section

    private var napsSection: some View {
        VStack(spacing: 0) {
            ForEach(selectedDayNaps) { nap in
                let napBreaks = selectedDayBreaks.filter { $0.parentNapID == nap.id }.sorted { $0.date < $1.date }
                let napEnd = nap.date.addingTimeInterval(TimeInterval(nap.duration * 60))
                let net = nap.totalMinutes(breaks: selectedDayBreaks)

                VStack(spacing: 0) {
                    // Nap row
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: nap.kind.icon)
                                .font(.system(size: 15, weight: .semibold))
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
                            Text(TimeFormat.minutes(net))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.indigo)
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

                    // Wake periods
                    if !napBreaks.isEmpty {
                        Divider().padding(.leading, 62)

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.indigo.opacity(0.10))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.indigo)
                            }

                            Text("Wake Periods")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                ForEach(napBreaks) { br in
                                    HStack(spacing: 8) {
                                        Text(TimeFormat.ampm(br.date))
                                            .monospacedDigit()
                                        Text("\(br.duration) min")
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                if nap.id != selectedDayNaps.last?.id {
                    Divider().padding(.leading, 62)
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

    // MARK: - Comparison Banner

    private var comparisonBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: vsYesterday >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(vsYesterday >= 0 ? .orange : .indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text("Compared to yesterday")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(vsYesterday == 0
                     ? "Same as yesterday"
                     : "\(vsYesterday > 0 ? "+" : "")\(TimeFormat.minutes(abs(vsYesterday))) \(vsYesterday > 0 ? "more" : "less") sleep")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(vsYesterday >= 0 ? .orange : .indigo)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.07))
        )
    }

    // MARK: - Week Chart

    private var weekChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Week Overview")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("Total Sleep")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TimeFormat.minutes(weekTotal))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.indigo)
            }

            Chart(weekChartData) { item in
                let isSelected = calendar.isDate(item.date, inSameDayAs: selectedDate)

                BarMark(
                    x: .value("Day", item.label),
                    y: .value("Min", animateChart ? item.minutes : 0)
                )
                .cornerRadius(8)
                .foregroundStyle(
                    isSelected
                    ? AnyShapeStyle(Color.orange)
                    : AnyShapeStyle(Color.indigo.opacity(0.20))
                )
                .annotation(position: .bottom) {
                    VStack(spacing: 1) {
                        if item.minutes > 0 {
                            Text(TimeFormat.minutes(item.minutes))
                                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .orange : .secondary)
                        } else {
                            Text("–")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary.opacity(0.4))
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
                AxisMarks { _ in AxisValueLabel().font(.caption2) }
            }
            .frame(height: 160)
            .onAppear {
                animateChart = false
                withAnimation(.easeOut(duration: 0.7)) { animateChart = true }
            }
            .onChange(of: selectedDate) { _ in
                animateChart = false
                withAnimation(.easeOut(duration: 0.5)) { animateChart = true }
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

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Naps between 11 AM – 1 PM tend to be longer and more refreshing for \(babyName).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("🤍")
                .font(.system(size: 32))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.06))
        )
    }
}
