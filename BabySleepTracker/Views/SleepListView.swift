//
//  SleepListView.swift
//  BabySleepTracker
//

import SwiftUI
import Foundation

struct SleepListView: View {

    // MARK: - Sheet routing

    struct SelectedDay: Identifiable {
        let id = UUID()
        let day: Date
    }

    enum ActiveSheet: Identifiable {
        case addSleep(editing: SleepRecord?)
        case addBreak(napID: UUID, date: Date, napDuration: Int)
        case dayDetail(SelectedDay)
        case wakeTime

        var id: String {
            switch self {
            case .addSleep(let editing):
                return "addSleep-\(editing?.id.uuidString ?? "new")"
            case .addBreak(let id, _, _):
                return "addBreak-\(id)"
            case .dayDetail(let day):
                return "dayDetail-\(day.id)"
            case .wakeTime:
                return "wakeTime"
            }
        }
    }

    private struct TimelineItem: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let time: String
        let title: String
        let detail: String
        let isActive: Bool
        let isFuture: Bool
        var awakeBeforeMinutes: Int
        
        init(icon: String, iconColor: Color, time: String,
                title: String, detail: String,
                isActive: Bool, isFuture: Bool,
                awakeBeforeMinutes: Int = 0) {  // ← default 0
               self.icon                = icon
               self.iconColor           = iconColor
               self.time                = time
               self.title               = title
               self.detail              = detail
               self.isActive            = isActive
               self.isFuture            = isFuture
               self.awakeBeforeMinutes  = awakeBeforeMinutes
           }
    }

    // MARK: - State

    @StateObject private var orchestrator = SleepCoachOrchestrator.shared
    @State private var activeSheet: ActiveSheet? = nil
    @State private var records: [SleepRecord] = []
    @State private var wakeRecords: [DailyWakeRecord] = []
    @State private var addDefaultDate: Date = Date()

    @AppStorage("babyName")   private var babyName:   String = "Baby"
    @AppStorage("parentName") private var parentName: String = ""

    // MARK: - Persistence
    
    private func upsert(_ record: SleepRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        saveRecords()
    }

    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: "sleepRecords")
            NotificationCenter.default.post(name: .sleepRecordsDidChange, object: nil)
        }
    }

    private func loadRecords() {
        if let data    = UserDefaults.standard.data(forKey: "sleepRecords"),
           let decoded = try? JSONDecoder().decode([SleepRecord].self, from: data) {
            records = decoded
        }
    }

    private func loadWakeRecords() {
        if let data    = UserDefaults.standard.data(forKey: "dailyWakeRecords_v1"),
           let decoded = try? JSONDecoder().decode([DailyWakeRecord].self, from: data) {
            wakeRecords = decoded
        }
    }

    private func saveWakeTime(_ selectedTime: Date) {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let comps    = calendar.dateComponents([.hour, .minute], from: selectedTime)
        guard let wakeTime = calendar.date(
            bySettingHour: comps.hour ?? 7,
            minute:        comps.minute ?? 0,
            second:        0,
            of:            today
        ) else { return }

        wakeRecords.removeAll { calendar.isDate($0.day, inSameDayAs: today) }
        wakeRecords.append(DailyWakeRecord(day: today, wakeTime: wakeTime))

        if let encoded = try? JSONEncoder().encode(wakeRecords) {
            UserDefaults.standard.set(encoded, forKey: "dailyWakeRecords_v1")
            NotificationCenter.default.post(name: .dailyWakeRecordsDidChange, object: nil)
        }
    }

    // MARK: - Derived Data

    private var sleeps: [SleepRecord] {
        records.filter { $0.kind != .break }.sorted { $0.date > $1.date }
    }

    private var breaks: [SleepRecord] {
        records.filter { $0.kind == .break }
    }

    private var latestSleep: SleepRecord? { sleeps.first }

    private var latestSleepMinutes: Int {
        guard let latestSleep else { return 95 }
        return latestSleep.totalMinutes(breaks: breaks)
    }

    private var todayRecords: [SleepRecord] {
        records.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todaySleeps: [SleepRecord] {
        todayRecords.filter { $0.kind != .break }.sorted { $0.date < $1.date }
    }

    private var todayWakeRecord: DailyWakeRecord? {
        wakeRecords.first { Calendar.current.isDateInToday($0.day) }
    }

    private var defaultWakeTime: Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var displayedParentName: String {
        let name = parentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "there" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var todayTotal: Int { totalMinutes(for: todayRecords) }

    private var yesterdayTotal: Int {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) else { return 0 }
        return totalMinutes(for: records.filter { cal.isDate($0.date, inSameDayAs: yesterday) })
    }

    private var todayDelta: Int { todayTotal - yesterdayTotal }

    private var last7DaysAverage: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totals = (0..<7).map { offset -> Int in
            let day   = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let items = records.filter { cal.isDate($0.date, inSameDayAs: day) }
            return totalMinutes(for: items)
        }
        return totals.reduce(0, +) / max(totals.count, 1)
    }

    private var previous7DaysAverage: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totals = (7..<14).map { offset -> Int in
            let day   = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let items = records.filter { cal.isDate($0.date, inSameDayAs: day) }
            return totalMinutes(for: items)
        }
        return totals.reduce(0, +) / max(totals.count, 1)
    }

    private var averageNapMinutes: Int {
        let comparable = sleeps.dropFirst().map { $0.totalMinutes(breaks: breaks) }
        guard !comparable.isEmpty else { return 80 }
        return comparable.reduce(0, +) / comparable.count
    }

    private var latestNapDelta: Int { latestSleepMinutes - averageNapMinutes }

    private var consistencyPercent: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totals = (0..<7).compactMap { offset -> Int? in
            let day   = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let items = records.filter { cal.isDate($0.date, inSameDayAs: day) }
            let t     = totalMinutes(for: items)
            return t > 0 ? t : nil
        }
        guard totals.count > 1 else { return records.isEmpty ? 87 : 74 }
        let avg      = Double(totals.reduce(0, +)) / Double(totals.count)
        let variance = totals.reduce(0.0) { $0 + pow(Double($1) - avg, 2) } / Double(totals.count)
        let dev      = sqrt(variance)
        return max(55, min(97, Int(100 - (dev / max(avg, 1) * 100))))
    }

    private var nextNapAnchor: Date {
        if let last = todaySleeps.last {
            return Calendar.current.date(
                byAdding: .minute, value: last.duration, to: last.date
            ) ?? last.date
        }
        return todayWakeRecord?.wakeTime ?? defaultWakeTime
    }

    private var recommendedWakeWindowMinutes: Int {
        if latestSleepMinutes >= 90 { return 130 }
        if latestSleepMinutes >= 60 { return 150 }
        return 120
    }

    private var nextNapTime: Date {
        if let t = orchestrator.snapshot?.daytime.nextNapTime { return t }
        return Calendar.current.date(
            byAdding: .minute, value: recommendedWakeWindowMinutes, to: nextNapAnchor
        ) ?? Date()
    }

    private var confidencePercent: Int {
        if let c = orchestrator.snapshot?.daytime.confidence { return c }
        let boost = todayWakeRecord == nil ? 0 : 6
        return min(94, 68 + boost + min(records.count, 9) * 2)
    }

    private var recommendationWindow: String {
        if let d = orchestrator.snapshot?.daytime {
            return "\(shortTime(d.windowStart)) – \(shortTime(d.windowEnd))"
        }
        let start = Calendar.current.date(byAdding: .minute, value: -15, to: nextNapTime) ?? nextNapTime
        let end   = Calendar.current.date(byAdding: .minute, value:  10, to: nextNapTime) ?? nextNapTime
        return "\(shortTime(start)) – \(shortTime(end))"
    }

    private var wakeWindowBeforeLatest: Int {
        guard let firstNap = todaySleeps
            .filter({ $0.kind == .dayNap })
            .sorted(by: { $0.date < $1.date })
            .first
        else { return 158 }

        if let wt = todayWakeRecord?.wakeTime {
            return max(0, Int(firstNap.date.timeIntervalSince(wt) / 60))
        }

        // Wake record yok — önceki naptan tahmin et
        let older = todaySleeps
            .filter { $0.date < firstNap.date }
            .sorted { $0.date > $1.date }

        if let prev = older.first,
           let prevEnd = Calendar.current.date(
               byAdding: .minute, value: prev.duration, to: prev.date
           ) {
            return max(0, Int(firstNap.date.timeIntervalSince(prevEnd) / 60))
        }

        return 120 // fallback
    }

    private var insightText: String {
        if let llm = orchestrator.llmResponse?.coachMessage, !llm.isEmpty { return llm }
        if orchestrator.isLLMLoading { return "Analyzing \(babyName)'s sleep patterns..." }
        return orchestrator.snapshot?.insights.coachTip
            ?? "Start with one sleep session and your baby's wake window will become easier to predict."
    }

    // MARK: - Timeline Items

    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        let sortedNaps = todaySleeps
            .filter { $0.kind == .dayNap }
            .sorted { $0.date < $1.date }

        // 1. Wake up — sadece günün başlangıcı
        let wakeUp: Date = {
            if let wt = todayWakeRecord?.wakeTime { return wt }
            if let first = sortedNaps.first {
                return Calendar.current.date(
                    byAdding: .minute,
                    value: -wakeWindowBeforeLatest,
                    to: first.date
                ) ?? first.date
            }
            return defaultWakeTime
        }()

        items.append(TimelineItem(
            icon: "sun.max.fill",
            iconColor: .sleepSun,
            time: shortTime(wakeUp),
            title: "Wake up",
            detail: "",
            isActive: false,
            isFuture: false
        ))

        // 2. Her nap — aralarında uyanıklık süresi yok, çizgide gösterilecek
        for (index, nap) in sortedNaps.enumerated() {
            let napEnd = Calendar.current.date(
                byAdding: .minute, value: nap.duration, to: nap.date
            ) ?? nap.date

            // Bir önceki bitiş saati (ilk nap için wake up)
            let prevEnd: Date = {
                if index == 0 { return wakeUp }
                let prev = sortedNaps[index - 1]
                return Calendar.current.date(
                    byAdding: .minute, value: prev.duration, to: prev.date
                ) ?? prev.date
            }()

            let awakeBeforeNap = max(0, Int(nap.date.timeIntervalSince(prevEnd) / 60))

            items.append(TimelineItem(
                icon: "moon.fill",
                iconColor: .sleepPurple,
                time: shortTime(nap.date),
                title: "Nap \(index + 1)",
                detail: TimeFormat.minutes(nap.totalMinutes(breaks: breaks)),
                isActive: index == sortedNaps.count - 1,
                isFuture: false,
                awakeBeforeMinutes: awakeBeforeNap
            ))
        }

        // 3. Bedtime veya next nap
        let lastNapEnd: Date? = sortedNaps.last.map {
            Calendar.current.date(byAdding: .minute, value: $0.duration, to: $0.date) ?? $0.date
        }

        let referenceTime = resolveReferenceTime()
        let awakeBeforeBed = lastNapEnd.map {
            max(0, Int(referenceTime.timeIntervalSince($0) / 60))
        } ?? max(0, Int(referenceTime.timeIntervalSince(wakeUp) / 60))

        items.append(nightOrNapTimelineItem(awakeBeforeMinutes: awakeBeforeBed))

        // Max 4 item — fazlaysa ilk + son 2 nap + bedtime
        if items.count > 4 {
            let first   = items[0]                    // Wake up
            let prelast = items[items.count - 2]      // Son nap
            let last    = items[items.count - 1]      // Bedtime
            // İkinci son napı da göster
            if items.count >= 4 {
                let secondLast = items[items.count - 3]
                return [first, secondLast, prelast, last]
            }
            return [first, prelast, last]
        }

        return items
    }

    private func resolveReferenceTime() -> Date {
        if orchestrator.snapshot?.nextSleepKind == .bedtime {
            return orchestrator.snapshot?.night.optimalBedtimeStart ?? nextNapTime
        }
        return nextNapTime
    }

    private func nightOrNapTimelineItem(awakeBeforeMinutes: Int) -> TimelineItem {
        let isBedtime = orchestrator.snapshot?.nextSleepKind == .bedtime

        if isBedtime {
            let bedtime = orchestrator.snapshot?.night.optimalBedtimeStart ?? nextNapTime
            return TimelineItem(
                icon: "moon.stars.fill",
                iconColor: .sleepPurpleDeep.opacity(0.6),
                time: "Bedtime",
                title: shortTime(bedtime),
                detail: "Night sleep",
                isActive: false,
                isFuture: true,
                awakeBeforeMinutes: awakeBeforeMinutes
            )
        }

        return TimelineItem(
            icon: "moon.fill",
            iconColor: .sleepPurple.opacity(0.45),
            time: "Next nap",
            title: shortTime(nextNapTime),
            detail: "~\(TimeFormat.minutes(orchestrator.snapshot?.daytime.expectedDurationMinutes ?? 90)) expected",
            isActive: false,
            isFuture: true,
            awakeBeforeMinutes: awakeBeforeMinutes
        )
    }

    // MARK: - Helpers

    private func totalMinutes(for items: [SleepRecord]) -> Int {
        let naps   = items.filter { $0.kind != .break }
        let breaks = items.filter { $0.kind == .break }
        return naps.reduce(0) { $0 + $1.totalMinutes(breaks: breaks) }
    }

    private func shortTime(_ date: Date) -> String {
        let f        = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func changeLabel(_ minutes: Int, fallback: String = "Collecting pattern") -> String {
        guard minutes != 0 else { return fallback }
        return "\(minutes > 0 ? "+" : "-")\(TimeFormat.minutes(abs(minutes)))"
    }

    private func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day)     { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }

    private func deleteDay(_ day: Date) {
        let cal = Calendar.current
        records.removeAll { cal.isDate($0.date, inSameDayAs: day) }
        saveRecords()
    }


    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    headerSection
                    totalSleepCard
                    nextNapOrBedtimeCard

                    if orchestrator.snapshot?.nextSleepKind == .nap {
                        bedtimeWindowCard
                    }

                    statsRow
                    todayTimelineCard
                    coachInsightCard
                    todayWakeUpCard

                    if !records.isEmpty { recentDaysSection }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                loadRecords()
                loadWakeRecords()
                orchestrator.loadCachedLLMResponse()
                orchestrator.generate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .sleepRecordsDidChange)) { _ in
                loadRecords()
                orchestrator.generate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dailyWakeRecordsDidChange)) { _ in
                loadWakeRecords()
                orchestrator.generate()
            }
            .environment(\.locale, Locale(identifier: "en_US"))
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {

            case .addSleep(let editing):
                AddRecordView(
                    defaultDate: addDefaultDate,
                    editingRecord: editing,
                    vm: AddRecordViewModel(),
                    onSave: { record in
                        upsert(record)
                    }
                )

            case .addBreak(let napID, let date, let napDuration):
                let existing = records.filter {
                    $0.parentNapID == napID && $0.kind == .break
                }
                AddBreakView(
                    defaultDate: date,
                    targetNapID: napID,
                    napDuration: napDuration,
                    existingBreaks: existing,
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
                    onDelete: { ids in
                        records.removeAll { ids.contains($0.id) }
                        saveRecords()
                    },
                    onAddSleep: { day in
                        addDefaultDate = day
                        activeSheet    = .addSleep(editing: nil)
                    },
                    onEditNap: { nap in
                        activeSheet = .addSleep(editing: nap)
                    },
                    onBreakSaved: { newBreak in
                        records.append(newBreak)
                        saveRecords()
                    }
                )

            case .wakeTime:
                WakeTimeEditorView(
                    initialTime: todayWakeRecord?.wakeTime ?? defaultWakeTime,
                    onSave: saveWakeTime
                )
            }
        }
    }
    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good day, \(displayedParentName) 👋")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Today's Sleep")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
            MoonHeaderArt()
                .frame(width: 64, height: 50)
        }
        .padding(.top, 6)
    }
    
    //MARK: Total Sleep Card
    
    private var totalSleepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL SLEEP TODAY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.sleepPurpleDeep)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(todayTotal / 60)")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("h")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Text("\(todayTotal % 60)")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("min")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }

                    Text(changeLabel(todayDelta))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(todayDelta >= 0 ? Color.sleepPurpleDeep : .orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Goal").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("14h").font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary)
                    Text("AAP guideline").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            ProgressView(value: min(Double(todayTotal), 840), total: 840)
                .tint(Color.sleepPurple)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: next nap or bedtime?
    
    private var nextNapOrBedtimeCard: some View {
        let isBedtime = orchestrator.snapshot?.nextSleepKind == .bedtime
        let displayTime = isBedtime
            ? (orchestrator.snapshot?.night.optimalBedtimeStart ?? nextNapTime)
            : nextNapTime
        let icon = isBedtime ? "moon.stars.fill" : "moon.fill"
        let label = isBedtime ? "BEDTIME" : "NEXT NAP"

        return Button {
            addDefaultDate = displayTime
            activeSheet = .addSleep(editing: nil)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.sleepPurpleDeep)
                    Text(shortTime(displayTime))
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Window: \(recommendationWindow)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.sleepPurpleDeep.opacity(0.8))
                }
                Spacer()
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(Color.sleepPurpleDeep).frame(width: 46, height: 46)
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                    Text("\(confidencePercent)% conf.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.sleepPurpleDeep)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.sleepPurple.opacity(0.12))
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }
     // MARK: Bedtime Window Card
    
    @ViewBuilder
    private var bedtimeWindowCard: some View {
        if let night = orchestrator.snapshot?.night {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BEDTIME WINDOW")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(shortTime(night.optimalBedtimeStart)) – \(shortTime(night.optimalBedtimeEnd))")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Overtired risk after \(shortTime(night.overtiredRiskTime))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Image(systemName: "moon.stars")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    
    //MARK: Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                title: "WAKE WINDOW",
                value: TimeFormat.minutes(
                    orchestrator.snapshot?.pattern?.averageWakeWindowMinutes ?? wakeWindowBeforeLatest
                ),
                subtitle: "Observed avg",
                subtitleColor: .secondary
            )
            statCard(
                title: "CONSISTENCY",
                value: consistencyPercent > 80 ? "Good" : "Building",
                subtitle: "\(consistencyPercent)% this week",
                subtitleColor: Color.sleepGreen
            )
        }
    }

    private func statCard(title: String, value: String, subtitle: String, subtitleColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    //MARK: Coach insight Card
    private var coachInsightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.sleepPurple.opacity(0.14)).frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.sleepPurpleDeep)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Coach Insight")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    if orchestrator.isLLMLoading {
                        ProgressView().scaleEffect(0.5).tint(Color.sleepPurpleDeep)
                    } else if orchestrator.llmResponse != nil {
                        Text("AI")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color.sleepPurpleDeep))
                    }
                }
                Text(insightText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.sleepStroke, lineWidth: 1)
        )
    }
    // MARK: Today Wakeup Card
    private var todayWakeUpCard: some View {
        Button { activeSheet = .wakeTime } label: {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.sleepSun)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's wake-up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(todayWakeRecord == nil
                             ? "Add the time \(babyName) woke up"
                             : "Used for predictions")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(todayWakeRecord.map { shortTime($0.wakeTime) } ?? "Add time")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(todayWakeRecord == nil ? Color.sleepPurpleDeep : .primary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.sleepStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    

    // MARK: - Timeline Card

    private var todayTimelineCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Today's Timeline")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.sleepInk)
                Spacer()
                Button {
                    activeSheet = .dayDetail(SelectedDay(day: Date()))
                } label: {
                    HStack(spacing: 7) {
                        Text("View full timeline")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.sleepPurpleDeep)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                    timelineNode(item)

                    if index < timelineItems.count - 1 {
                        timelineSegment(
                            awakeMinutes: timelineItems[index + 1].awakeBeforeMinutes,
                            isDashed: timelineItems[index + 1].isFuture
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.sleepInk.opacity(0.05), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.sleepStroke, lineWidth: 1)
        )
    }

    private func timelineNode(_ item: TimelineItem) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(item.iconColor.opacity(item.isFuture ? 0.06 : 0.12))
                    .frame(width: 34, height: 34)
                if item.isFuture {
                    Circle()
                        .strokeBorder(item.iconColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 34, height: 34)
                }
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.iconColor)
            }
            VStack(spacing: 1) {
                Text(item.time).font(.system(size: 9)).foregroundStyle(.secondary)
                Text(item.title).font(.system(size: 10, weight: .semibold))
                if !item.detail.isEmpty {
                    Text(item.detail).font(.system(size: 9, weight: .semibold)).foregroundStyle(item.iconColor)
                }
            }
        }
        .frame(width: 58)
    }

    private func timelineSegment(awakeMinutes: Int, isDashed: Bool) -> some View {
        VStack(spacing: 2) {
            if isDashed {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 1.5)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.sleepStroke, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    )
            } else {
                Rectangle()
                    .fill(Color.sleepStroke)
                    .frame(height: 1.5)
            }
            Text(awakeMinutes > 0 ? TimeFormat.minutes(awakeMinutes) : "")
                .font(.system(size: 8))
                .foregroundStyle(Color.sleepMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 17)
    }

    private func timelineColumn(_ item: TimelineItem) -> some View {
        ZStack(alignment: .top) {

            // Uyanıklık süresi — çizginin üstünde ortalanmış
            if item.awakeBeforeMinutes > 0 {
                Text(TimeFormat.minutes(item.awakeBeforeMinutes))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.sleepMuted)
                    .offset(x: -22, y: 68)   // çizgi hizası
            }

            VStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.iconColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(item.iconColor.opacity(item.isFuture ? 0.08 : 0.12))
                    )
                Circle()
                    .fill(item.isActive ? Color.sleepPurpleDeep : Color.sleepStroke)
                    .frame(
                        width:  item.isActive ? 12 : 10,
                        height: item.isActive ? 12 : 10
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                VStack(spacing: 5) {
                    Text(item.time)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.sleepMuted)
                        .lineLimit(1).minimumScaleFactor(0.68)
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.sleepInk)
                        .lineLimit(2).minimumScaleFactor(0.72)
                        .multilineTextAlignment(.center)
                    Text(item.detail)
                        .font(.system(size: 13,
                                      weight: item.isActive ? .bold : .medium))
                        .foregroundStyle(
                            item.isActive ? Color.sleepPurpleDeep : Color.sleepMuted
                        )
                        .lineLimit(2).minimumScaleFactor(0.68)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Recent Days

    private var recentDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sleep")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.sleepInk).padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(
                    Array(groupedByDay.prefix(3).enumerated()),
                    id: \.element.day
                ) { index, group in
                    Button {
                        activeSheet = .dayDetail(SelectedDay(day: group.day))
                    } label: {
                        dayRow(group: group)
                    }
                    .buttonStyle(CardPressButtonStyle())
                    if index < min(groupedByDay.count, 3) - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.sleepStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var groupedByDay: [(day: Date, items: [SleepRecord])] {
        let cal    = Calendar.current
        let groups = Dictionary(grouping: records) { cal.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private func dayRow(group: (day: Date, items: [SleepRecord])) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.sleepPurple.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.sleepPurpleDeep)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(dayTitle(group.day))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.sleepInk)
                Text("\(group.items.filter { $0.kind != .break }.count) sessions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.sleepMuted)
            }
            Spacer()
            HStack(spacing: 7) {
                Text(TimeFormat.minutes(totalMinutes(for: group.items)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.sleepInk)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.sleepPurpleDeep)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { deleteDay(group.day) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Wake Time Editor

private struct WakeTimeEditorView: View {
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date

    init(initialTime: Date, onSave: @escaping (Date) -> Void) {
        self.onSave   = onSave
        _selectedTime = State(initialValue: initialTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.sleepSun.opacity(0.12)).frame(width: 58, height: 58)
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Color.sleepSun)
                }
                VStack(spacing: 6) {
                    Text("When did your baby wake up?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.sleepInk)
                        .multilineTextAlignment(.center)
                    Text("This time becomes the starting point for today's sleep predictions.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.sleepMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                DatePicker(
                    "Wake-up time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel).labelsHidden()
                .frame(maxHeight: 150).clipped()
                Spacer()
            }
            .padding(.top, 24)
            .background(Color.sleepBackground)
            .navigationTitle("Today's Wake-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave(selectedTime); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(Color.sleepPurpleDeep)
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Decorative Views

private struct MoonHeaderArt: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let s = min(w, h)
            ZStack {
                Image(systemName: "star.fill")
                    .font(.system(size: s * 0.16, weight: .semibold))
                    .foregroundStyle(Color.sleepSun.opacity(0.85))
                    .position(x: w * 0.88, y: h * 0.20)
                Image(systemName: "sparkle")
                    .font(.system(size: s * 0.13, weight: .bold))
                    .foregroundStyle(Color.sleepPurple.opacity(0.55))
                    .position(x: w * 0.12, y: h * 0.32)
                Image(systemName: "moon.fill")
                    .font(.system(size: s * 0.78))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.white.opacity(0.84), Color.sleepLilac, Color.sleepPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .rotationEffect(.degrees(-12))
                    .shadow(color: Color.sleepPurple.opacity(0.18),
                            radius: s * 0.10, x: 0, y: s * 0.06)
                    .position(x: w * 0.56, y: h * 0.43)
                HStack(spacing: -s * 0.08) {
                    Circle().fill(Color.white.opacity(0.88)).frame(width: s*0.28, height: s*0.28)
                    Circle().fill(Color.white.opacity(0.94)).frame(width: s*0.38, height: s*0.38)
                    Circle().fill(Color.white.opacity(0.88)).frame(width: s*0.28, height: s*0.28)
                }.position(x: w * 0.57, y: h * 0.78)
                VStack(spacing: s * 0.025) {
                    HStack(spacing: s * 0.14) {
                        SleepArcEye().frame(width: s * 0.13, height: s * 0.08)
                        SleepArcEye().frame(width: s * 0.13, height: s * 0.08)
                    }
                    SleepSmile()
                        .stroke(Color.sleepPurpleDeep,
                                style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .frame(width: s * 0.20, height: s * 0.10)
                }.position(x: w * 0.55, y: h * 0.50)
            }
            .frame(width: w, height: h)
        }
    }
}


private struct SleepArcEye: View {
    var body: some View {
        ArcShape()
            .stroke(Color.sleepPurpleDeep,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
}

private struct SleepSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return p
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return p
    }
}

// MARK: - Colors

private extension Color {
    static let sleepBackground = Color("sleepBackground")
       static let sleepInk        = Color("sleepInk")
       static let sleepMuted      = Color("sleepMuted")
       static let sleepPurple     = Color("sleepPurple")
       static let sleepPurpleDeep = Color("sleepPurpleDeep")
       static let sleepLilac      = Color("sleepLilac")
       static let sleepSun        = Color("sleepSun")
       static let sleepCloud      = Color("sleepCloud")
       static let sleepGreen      = Color("sleepGreen")
       static let sleepStroke     = Color("sleepStroke")
       static let sleepWarmCard   = Color("sleepWarmCard")

    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xff) / 255,
            green:   Double((hex >>  8) & 0xff) / 255,
            blue:    Double( hex         & 0xff) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let sleepRecordsDidChange     = Notification.Name("sleepRecordsDidChange")
    static let dailyWakeRecordsDidChange = Notification.Name("dailyWakeRecordsDidChange")
}

// MARK: - Button Style

struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
