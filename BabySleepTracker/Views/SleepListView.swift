import SwiftUI
import Foundation
import Charts

struct SleepListView: View {

    // MARK: - Sheet routing
    struct SelectedDay: Identifiable {
        let id = UUID()
        let day: Date
    }

    enum ActiveSheet: Identifiable {
        case addSleep
        case addBreak
        case dayDetail(SelectedDay)

        var id: String {
            switch self {
            case .addSleep: return "addSleep"
            case .addBreak: return "addBreak"
            case .dayDetail(let d): return "dayDetail-\(d.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil
    @State private var records: [SleepRecord] = []
    @State private var animateChart = false
    @State private var addDefaultDate: Date = Date()
    @State private var breakDefaultDate: Date = Date()
    @State private var breakTargetDay: Date = Date()
    @State private var selectedNapIDForBreak: UUID? = nil

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

    private var sortedRecords: [SleepRecord] {
        records.sorted { $0.date > $1.date }
    }

    private var groupedByDay: [(day: Date, items: [SleepRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
        return groups
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    struct DailySleep: Identifiable {
        let id = UUID()
        let date: Date
        let totalMinutes: Int
    }

    private var todayTotal: Int {
        let calendar = Calendar.current
        let todayRecords = records.filter { calendar.isDateInToday($0.date) }
        return totalMinutes(for: todayRecords)
    }

    private var last7DaysAverage: Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let lastWeekRecords = records.filter { $0.date >= sevenDaysAgo }
        guard !lastWeekRecords.isEmpty else { return 0 }
        let grouped = Dictionary(grouping: lastWeekRecords) {
            calendar.startOfDay(for: $0.date)
        }
        let dailyTotals = grouped.values.map { totalMinutes(for: Array($0)) }
        return dailyTotals.reduce(0, +) / 7
    }

    private var last7DaysData: [DailySleep] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return DailySleep(date: day, totalMinutes: totalMinutes(for: dayRecords))
        }
    }

    private func totalMinutes(for items: [SleepRecord]) -> Int {
        let naps = items.filter { $0.kind != .break }
        let breaks = items.filter { $0.kind == .break }
        return naps.reduce(0) { $0 + $1.totalMinutes(breaks: breaks) }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }

    private func deleteDay(_ day: Date) {
        let cal = Calendar.current
        records.removeAll { cal.isDate($0.date, inSameDayAs: day) }
        saveRecords()
    }

    // MARK: - Chart max Y

    private var chartMaxMinutes: Int {
        let maxVal = last7DaysData.map { $0.totalMinutes }.max() ?? 0
        let hours = max(1, Int(ceil(Double(maxVal) / 60.0)))
        return hours * 60
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Metric Cards ──
                    metricCards

                    // ── Chart Card ──
                    chartCard

                    // ── Day List Card ──
                    if !groupedByDay.isEmpty {
                        dayListCard
                    }

                    // ── Tip Banner ──
                    tipBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Umay's Nap")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            addDefaultDate = Date()
                            activeSheet = .addSleep
                        } label: {
                            Label("Add Nap", systemImage: "plus.circle")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.indigo.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.indigo)
                        }
                    }
                }
            }
            .onAppear { loadRecords() }
            .environment(\.locale, Locale(identifier: "en_US"))
            .overlay {
                if sortedRecords.isEmpty {
                    emptyState
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addSleep:
                AddRecordView(
                    defaultDate: addDefaultDate,
                    vm: AddRecordViewModel(),
                    onSave: { newRecord in
                        records.append(newRecord)
                        saveRecords()
                    }
                )
            case .addBreak:
                AddBreakView(
                    defaultDate: breakDefaultDate,
                    targetNapID: selectedNapIDForBreak,
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
                    onAddSleep: { day in
                        addDefaultDate = day
                        activeSheet = .addSleep
                    },
                    onBreakSaved: { newBreak in
                        records.append(newBreak)
                        saveRecords()
                    }
                )
            }
        }
    }

    // MARK: - Metric Cards

    private var metricCards: some View {
        HStack(spacing: 12) {
            // Today
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(TimeFormat.minutes(todayTotal))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )

            // 7-day avg
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("7-day avg")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(TimeFormat.minutes(last7DaysAverage))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
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

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Last 7 Days")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                // "Total time" static badge
                HStack(spacing: 4) {
                    Text("Total time")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }

            Chart(last7DaysData) { item in
                let isToday = Calendar.current.isDateInToday(item.date)

                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Minutes", animateChart ? item.totalMinutes : 0)
                )
                .cornerRadius(6)
                .foregroundStyle(
                    isToday
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Color.indigo, Color.indigo.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(Color.indigo.opacity(0.18))
                )
                .annotation(position: .top) {
                    if isToday && item.totalMinutes > 0 {
                        Text(TimeFormat.minutes(item.totalMinutes))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .chartYScale(domain: 0...chartMaxMinutes)
            .chartYAxis {
                AxisMarks(values: stride(from: 0, through: chartMaxMinutes, by: 60 * 5).map { $0 }) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes / 60)h")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.padding(.horizontal, 4)
            }
            .frame(height: 180)
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

    // MARK: - Day List Card (tek kart, separator ile)

    private var dayListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(groupedByDay.enumerated()), id: \.element.day) { index, group in
                Button {
                    activeSheet = .dayDetail(SelectedDay(day: group.day))
                } label: {
                    dayRow(group: group)
                }
                .buttonStyle(CardPressButtonStyle())

                if index < groupedByDay.count - 1 {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .clipped()
    }

    private func dayRow(group: (day: Date, items: [SleepRecord])) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dayTitle(group.day))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(group.items.filter { $0.kind != .break }.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(TimeFormat.minutes(totalMinutes(for: group.items)))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                deleteDay(group.day)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Tip Banner

    private var tipBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.indigo)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Tip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                Text("Short naps (10–90 min) can boost alertness, mood, and performance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.indigo.opacity(0.06))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("No sleep records yet")
                .font(.headline)
            Text("Tap the + button to add your first sleep session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                addDefaultDate = Date()
                activeSheet = .addSleep
            } label: {
                Label("Add Sleep", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.indigo, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - CardPressButtonStyle

struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
