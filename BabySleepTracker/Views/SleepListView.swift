//
//  SleepListView.swift
//  BabyTracker
//
//  Created by MacBook on 21.01.2026.
//

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
        case pickNapForBreak
        case addBreak
        case dayDetail(SelectedDay)

        var id: String {
            switch self {
            case .addSleep: return "addSleep"
            case .pickNapForBreak: return "pickNapForBreak"
            case .addBreak: return "addBreak"
            case .dayDetail(let d): return "dayDetail-\(d.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil

    // MARK: - Data
    @State private var records: [SleepRecord] = [
        SleepRecord(date: Date(), duration: 90),
        SleepRecord(date: Date().addingTimeInterval(-86400), duration: 120),
        SleepRecord(date: Date().addingTimeInterval(-86400), duration: 120)
    ]

    // MARK: - UI state
    @State private var animateChart = false

    // Add Sleep
    @State private var addDefaultDate: Date = Date()

    // Add Break
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
        return records
            .filter { calendar.isDateInToday($0.date) }
            .map { $0.duration }
            .reduce(0, +)
    }

    private var last7DaysAverage: Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let lastWeek = records.filter { $0.date >= sevenDaysAgo }
        guard !lastWeek.isEmpty else { return 0 }

        let total = lastWeek.map { $0.duration }.reduce(0, +)
        return total / 7
    }

    private var last7DaysData: [DailySleep] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!

            let total = records
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .map { $0.duration }
                .reduce(0, +)

            return DailySleep(date: day, totalMinutes: total)
        }
    }

    // MARK: - UI pieces
    private var statsHeader: some View {
        HStack(spacing: 12) {
            MetricCard("Today", TimeFormat.minutes(todayTotal), emphasized: true)
            MetricCard("7-day avg", TimeFormat.minutes(last7DaysAverage), emphasized: false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var sleepChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 7 Days")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(last7DaysData) { item in
                let isToday = Calendar.current.isDateInToday(item.date)

                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Minutes", animateChart ? item.totalMinutes : 0)
                )
                .cornerRadius(8)
                .opacity(isToday ? 1.0 : 0.28)
                .foregroundStyle(
                    isToday
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [.indigo, .indigo.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(Color.indigo.opacity(0.25))
                )
                .annotation(position: .top) {
                    if isToday, let label = hoursLabel(from: item.totalMinutes) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.padding(.horizontal, 6)
            }
            .onAppear {
                animateChart = false
                withAnimation(.easeOut(duration: 0.7)) { animateChart = true }
            }
            .onChange(of: records.count) { _ in
                animateChart = false
                withAnimation(.easeInOut(duration: 0.6)) { animateChart = true }
            }
            .frame(height: 120)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    struct MetricCard: View {
        let title: String
        let value: String
        let emphasized: Bool

        init(_ title: String, _ value: String, emphasized: Bool = true) {
            self.title = title
            self.value = value
            self.emphasized = emphasized
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(emphasized ? .title3.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func hoursLabel(from minutes: Int) -> String? {
        guard minutes > 0 else { return nil }
        let hours = Double(minutes) / 60.0

        if hours >= 1, abs(hours - round(hours)) < 0.0001 {
            return "\(Int(round(hours)))h"
        }
        return String(format: "%.1fh", hours)
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }

    private func totalMinutes(for items: [SleepRecord]) -> Int {
        items.map { $0.duration }.reduce(0, +)
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }

    struct DayRowCard: View {
        let title: String
        let sessionCount: Int
        let totalText: String
        let highlightToday: Bool

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))

                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)

                        if highlightToday && title != "Today" {
                            Text("Today")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                                .overlay(Capsule().stroke(Color.indigo.opacity(0.25), lineWidth: 1))
                                .foregroundStyle(.indigo)
                        }
                    }

                    Text("\(sessionCount) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Text(totalText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    struct CardPressButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.92 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }

    private func deleteDay(_ day: Date) {
        let cal = Calendar.current
        records.removeAll { cal.isDate($0.date, inSameDayAs: day) }
        saveRecords()
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !records.isEmpty {
                        sleepChartCard
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(groupedByDay, id: \.day) { group in
                        Button {
                            activeSheet = .dayDetail(SelectedDay(day: group.day))
                        } label: {
                            DayRowCard(
                                title: dayTitle(group.day),
                                sessionCount: group.items.count,
                                totalText: TimeFormat.minutes(totalMinutes(for: group.items)),
                                highlightToday: isToday(group.day)
                            )
                        }
                        .buttonStyle(CardPressButtonStyle())
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteDay(group.day)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                addDefaultDate = group.day
                                activeSheet = .addSleep
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                            .tint(.indigo)
                        }
                    }
                } header: {
                    statsHeader
                        .textCase(nil)
                        .padding(.top, 8)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .overlay {
                if sortedRecords.isEmpty {
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
                }
            }
            .navigationTitle("Naps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            addDefaultDate = Date()
                            activeSheet = .addSleep
                        } label: {
                            Label("Add Nap", systemImage: "plus.circle")
                        }

                        Button {
                            breakTargetDay = Date()
                            activeSheet = .pickNapForBreak
                        } label: {
                            Label("Add Break", systemImage: "cup.and.saucer.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadRecords() }
            .environment(\.locale, Locale(identifier: "en_US"))
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

            case .pickNapForBreak:
                let naps = records
                    .filter { Calendar.current.isDate($0.date, inSameDayAs: breakTargetDay) }
                    .filter { $0.kind == .dayNap || $0.kind == .nightSleep }
                    .sorted { $0.date < $1.date }

                NapPickerView(naps: naps) { selectedNap in
                    selectedNapIDForBreak = selectedNap.id
                    breakDefaultDate = breakTargetDay
                    activeSheet = .addBreak
                }

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
                    onAddTap: { mode, day, targetNapID in
                        switch mode {
                        case .sleep:
                            addDefaultDate = day
                            activeSheet = .addSleep

                        case .break:
                            breakTargetDay = day

                            if let id = targetNapID {
                                selectedNapIDForBreak = id
                                breakDefaultDate = day
                                activeSheet = .addBreak
                            } else {
                                activeSheet = .pickNapForBreak
                            }
                        }
                    }
                )
            }
        }
    }
}
