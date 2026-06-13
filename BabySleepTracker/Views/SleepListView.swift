import SwiftUI
import Foundation

struct SleepListView: View {

    // MARK: - Sheet routing

    struct SelectedDay: Identifiable {
        let id = UUID()
        let day: Date
    }

    enum ActiveSheet: Identifiable {
        case addSleep
        case addBreak(napID: UUID, date: Date, napDuration: Int)
        case dayDetail(SelectedDay)
        case wakeTime

        var id: String {
            switch self {
            case .addSleep:                    return "addSleep"
            case .addBreak(let id, _, _):      return "addBreak-\(id)"
            case .dayDetail(let day):          return "dayDetail-\(day.id)"
            case .wakeTime:                    return "wakeTime"
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
    }

    // MARK: - State

    @StateObject private var orchestrator = SleepCoachOrchestrator.shared
    @State private var activeSheet: ActiveSheet? = nil
    @State private var records: [SleepRecord] = []
    @State private var wakeRecords: [DailyWakeRecord] = []
    @State private var addDefaultDate: Date = Date()

    @AppStorage("babyName")   private var babyName:    String = "Baby"
    @AppStorage("parentName") private var parentName:  String = ""

    // MARK: - Persistence

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
            return Calendar.current.date(byAdding: .minute, value: last.duration, to: last.date) ?? last.date
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
        guard let latest = todaySleeps.last else { return 158 }
        let older = todaySleeps
            .filter { $0.id != latest.id && $0.date < latest.date }
            .sorted { $0.date > $1.date }
        if let prev = older.first,
           let prevEnd = Calendar.current.date(byAdding: .minute, value: prev.duration, to: prev.date) {
            return max(0, Int(latest.date.timeIntervalSince(prevEnd) / 60))
        }
        if let wt = todayWakeRecord?.wakeTime {
            return max(0, Int(latest.date.timeIntervalSince(wt) / 60))
        }
        return 158
    }

    private var insightText: String {
        orchestrator.snapshot?.insights.coachTip
            ?? "Start with one sleep session and your baby's wake window will become easier to predict."
    }

    // MARK: - Timeline Items

    private var timelineItems: [TimelineItem] {
        if let first = todaySleeps.first {
            let wakeUp   = todayWakeRecord?.wakeTime
                ?? Calendar.current.date(byAdding: .minute, value: -wakeWindowBeforeLatest, to: first.date)
                ?? Date()
            let firstEnd = Calendar.current.date(byAdding: .minute, value: first.duration, to: first.date) ?? first.date
            let awakeAfter = max(0, Int(nextNapTime.timeIntervalSince(firstEnd) / 60))
            return [
                TimelineItem(icon: "sun.max.fill",  iconColor: .sleepSun,
                             time: shortTime(wakeUp),     title: "Wake up",
                             detail: "\(TimeFormat.minutes(wakeWindowBeforeLatest)) awake",
                             isActive: false, isFuture: false),
                TimelineItem(icon: "moon.fill",      iconColor: .sleepPurple,
                             time: shortTime(first.date), title: "Nap 1",
                             detail: TimeFormat.minutes(first.totalMinutes(breaks: breaks)),
                             isActive: true,  isFuture: false),
                TimelineItem(icon: "sun.max.fill",  iconColor: .sleepSun,
                             time: shortTime(firstEnd),   title: "Wake up",
                             detail: "\(TimeFormat.minutes(awakeAfter)) awake",
                             isActive: false, isFuture: false),
                TimelineItem(icon: "moon.fill",      iconColor: .sleepPurple.opacity(0.45),
                             time: "Next nap",            title: shortTime(nextNapTime),
                             detail: "~1h 30m expected",
                             isActive: false, isFuture: true)
            ]
        }
        if let wt = todayWakeRecord?.wakeTime {
            let awake = max(0, Int(nextNapTime.timeIntervalSince(wt) / 60))
            return [
                TimelineItem(icon: "sun.max.fill", iconColor: .sleepSun,
                             time: shortTime(wt), title: "Wake up",
                             detail: "\(TimeFormat.minutes(awake)) awake",
                             isActive: true,  isFuture: false),
                TimelineItem(icon: "moon.fill",    iconColor: .sleepPurple.opacity(0.45),
                             time: "Next nap",     title: shortTime(nextNapTime),
                             detail: "~1h 30m expected",
                             isActive: false, isFuture: true)
            ]
        }
        return [
            TimelineItem(icon: "sun.max.fill", iconColor: .sleepSun.opacity(0.55),
                         time: "Not added",    title: "Wake up",
                         detail: "Add wake time",
                         isActive: false, isFuture: true),
            TimelineItem(icon: "moon.fill",    iconColor: .sleepPurple.opacity(0.45),
                         time: "Next nap",     title: shortTime(nextNapTime),
                         detail: "Low confidence",
                         isActive: false, isFuture: true)
        ]
    }

    // MARK: - Helpers

    private func totalMinutes(for items: [SleepRecord]) -> Int {
        let naps   = items.filter { $0.kind != .break }
        let breaks = items.filter { $0.kind == .break }
        return naps.reduce(0) { $0 + $1.totalMinutes(breaks: breaks) }
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
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
                VStack(spacing: 16) {
                    headerSection
                    sleepCoachCard
                    summaryStatsCard
                    wakeTimeCard
                    nextNapCard
                    todayTimelineCard
                    if !records.isEmpty { recentDaysSection }
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 112)
            }
            .background(Color.sleepBackground)
            .navigationBarHidden(true)
            .onAppear {
                loadRecords()
                loadWakeRecords()
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
            case .addSleep:
                AddRecordView(
                    defaultDate: addDefaultDate,
                    vm: AddRecordViewModel(),
                    onSave: { newRecord in
                        records.append(newRecord)
                        saveRecords()
                    }
                )
            case .addBreak(let napID, let date, let napDuration):
                let existing = records.filter { $0.parentNapID == napID && $0.kind == .break }
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
                        activeSheet    = .addSleep
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 11) {
                Text("Hello, \(displayedParentName) 👋")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.sleepInk)
                    .lineLimit(1).minimumScaleFactor(0.72)
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.sleepPurple)
                    Text("\(babyName)'s AI Sleep Coach is here")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.sleepMuted)
                        .lineLimit(1).minimumScaleFactor(0.78)
                }
            }
            Spacer(minLength: 4)
            MoonHeaderArt()
                .frame(width: 88, height: 70)
                .padding(.top, -12)
        }
    }

    // MARK: - Sleep Coach Card

    private var sleepCoachCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.sleepPurple, Color.sleepLilac, Color.sleepPurpleDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("✦ AI SLEEP COACH")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Color.sleepPurpleDeep.opacity(0.52)))

                        VStack(alignment: .leading, spacing: 7) {
                            Text(latestSleep == nil ? "Ready for a nap!" : "Great nap! 💜")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.76)
                            Text(latestSleep == nil ? "\(babyName) can start today" : "\(babyName) slept")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.84))
                            Text(latestSleep == nil ? "No sleep yet" : TimeFormat.minutes(latestSleepMinutes))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.74)
                        }
                        trendPill
                    }
                    Spacer(minLength: 8)
                    SleepFaceProgress(progress: Double(consistencyPercent) / 100)
                        .frame(width: 88, height: 88)
                        .padding(.top, 34)
                }
                Button { activeSheet = .dayDetail(SelectedDay(day: Date())) } label: {
                    coachInsight
                }
                .buttonStyle(CardPressButtonStyle())
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendPill: some View {
        let hasData  = latestSleep != nil
        let positive = latestNapDelta >= 0
        return HStack(spacing: 7) {
            Image(systemName: hasData ? (positive ? "arrow.up" : "arrow.down") : "sparkles")
                .font(.system(size: 11, weight: .bold))
            Text(hasData
                 ? "\(TimeFormat.minutes(abs(latestNapDelta))) \(positive ? "longer" : "shorter") than predicted"
                 : "Add a session for predictions")
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.78)
        }
        .foregroundStyle(hasData && !positive ? Color.orange : Color.sleepGreen)
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.74)))
    }

    private var coachInsight: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.sleepPurpleDeep)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text("Coach Insight")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.sleepInk)
                Text(insightText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.sleepInk)
                    .lineSpacing(2).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.sleepInk)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
    }

    // MARK: - Stats

    private var summaryStatsCard: some View {
        HStack(alignment: .top, spacing: 0) {
            metricItem(icon: "moon.fill",  iconColor: .sleepPurple,
                       title: "Today",    value: TimeFormat.minutes(todayTotal),
                       change: changeLabel(todayDelta))
            Divider().padding(.vertical, 12)
            metricItem(icon: "cloud.fill", iconColor: .sleepCloud,
                       title: "7-Day Avg", value: TimeFormat.minutes(last7DaysAverage),
                       change: changeLabel(last7DaysAverage - previous7DaysAverage))
            Divider().padding(.vertical, 12)
            consistencyItem
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.sleepInk.opacity(0.05), radius: 14, x: 0, y: 7)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.sleepStroke, lineWidth: 1))
    }

    private func metricItem(icon: String, iconColor: Color,
                            title: String, value: String, change: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(iconColor.opacity(0.11)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(iconColor)
            }
            VStack(spacing: 3) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.sleepInk)
                    .lineLimit(2).multilineTextAlignment(.center)
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Color.sleepInk)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(change).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(change.hasPrefix("-") ? Color.orange : Color.sleepGreen)
                    .lineLimit(1).minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 6)
    }

    private var consistencyItem: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.sleepSun.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "star.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.sleepSun)
            }
            VStack(spacing: 3) {
                Text("Consistency").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.sleepInk)
                    .lineLimit(1).minimumScaleFactor(0.62)
                Text(consistencyPercent > 80 ? "Good" : "Building")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.sleepInk)
                    .lineLimit(1).minimumScaleFactor(0.66)
            }
            ZStack {
                Circle().stroke(Color.sleepPurple.opacity(0.12), lineWidth: 4)
                Circle().trim(from: 0, to: Double(consistencyPercent) / 100)
                    .stroke(Color.sleepPurpleDeep, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(consistencyPercent)%").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.sleepInk)
            }
            .frame(width: 36, height: 36)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 6)
    }

    // MARK: - Wake Time Card

    private var wakeTimeCard: some View {
        Button { activeSheet = .wakeTime } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.sleepSun.opacity(0.12)).frame(width: 42, height: 42)
                    Image(systemName: "sunrise.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(Color.sleepSun)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Wake-up").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sleepInk)
                    Text(todayWakeRecord == nil
                         ? "Add the time \(babyName) woke up"
                         : "Used to calculate the next sleep window")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.sleepMuted)
                        .lineLimit(1).minimumScaleFactor(0.78)
                }
                Spacer(minLength: 8)
                Text(todayWakeRecord.map { shortTime($0.wakeTime) } ?? "Add time")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(todayWakeRecord == nil ? Color.sleepPurpleDeep : Color.sleepInk)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.sleepPurple.opacity(0.09)))
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sleepPurpleDeep)
            }
            .padding(13).contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.sleepInk.opacity(0.04), radius: 12, x: 0, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.sleepStroke, lineWidth: 1))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    // MARK: - Next Nap Card

    private var nextNapCard: some View {
        VStack(spacing: 12) {
            Button {
                addDefaultDate = nextNapTime
                activeSheet    = .addSleep
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle().fill(Color.sleepSun.opacity(0.13)).frame(width: 44, height: 44)
                        Image(systemName: "sun.max.fill").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.sleepSun)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Next Nap").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.sleepInk)
                            Image(systemName: "info.circle").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.sleepPurpleDeep)
                        }
                        Text(shortTime(nextNapTime))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.sleepInk)
                            .lineLimit(1).minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: 4)
                    VStack(spacing: 4) {
                        Text("\(confidencePercent)%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.sleepPurpleDeep)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.sleepPurple.opacity(0.12)))
                        Text("Confidence").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.sleepInk)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sleepPurpleDeep)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(CardPressButtonStyle())

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended window").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.sleepPurpleDeep)
                    Text(recommendationWindow).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.sleepInk)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.sleepPurple.opacity(0.09)))
                Spacer()
            }
            .padding(.leading, 54)

            Divider().background(Color.sleepStroke)

            Button { activeSheet = .dayDetail(SelectedDay(day: Date())) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.sleepPurpleDeep)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.sleepPurple.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Why this recommendation?").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sleepInk)
                        Text("Based on science, \(babyName)'s patterns and today's data.")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.sleepMuted).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sleepPurpleDeep)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(CardPressButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.sleepWarmCard)
                .shadow(color: Color.sleepSun.opacity(0.07), radius: 14, x: 0, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.sleepSun.opacity(0.13), lineWidth: 1))
    }

    // MARK: - Timeline

    private var todayTimelineCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Today's Timeline")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.sleepInk)
                Spacer()
                Button { activeSheet = .dayDetail(SelectedDay(day: Date())) } label: {
                    HStack(spacing: 7) {
                        Text("View full timeline").font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.sleepPurpleDeep)
                }
                .buttonStyle(.plain)
            }
            ZStack(alignment: .top) {
                Rectangle().fill(Color.sleepStroke).frame(height: 2)
                    .padding(.horizontal, 26).offset(y: 62)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(timelineItems) { item in
                        timelineColumn(item).frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(minHeight: 132)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.sleepInk.opacity(0.05), radius: 16, x: 0, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.sleepStroke, lineWidth: 1))
    }

    private func timelineColumn(_ item: TimelineItem) -> some View {
        VStack(spacing: 9) {
            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(item.iconColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(item.iconColor.opacity(item.isFuture ? 0.08 : 0.12)))
            Circle()
                .fill(item.isActive ? Color.sleepPurpleDeep : Color.sleepStroke)
                .frame(width: item.isActive ? 12 : 10, height: item.isActive ? 12 : 10)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
            VStack(spacing: 5) {
                Text(item.time).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.sleepMuted)
                    .lineLimit(1).minimumScaleFactor(0.68)
                Text(item.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sleepInk)
                    .lineLimit(2).minimumScaleFactor(0.72).multilineTextAlignment(.center)
                Text(item.detail)
                    .font(.system(size: 13, weight: item.isActive ? .bold : .medium))
                    .foregroundStyle(item.isActive ? Color.sleepPurpleDeep : Color.sleepMuted)
                    .lineLimit(2).minimumScaleFactor(0.68).multilineTextAlignment(.center)
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
                ForEach(Array(groupedByDay.prefix(3).enumerated()), id: \.element.day) { index, group in
                    Button { activeSheet = .dayDetail(SelectedDay(day: group.day)) } label: {
                        dayRow(group: group)
                    }
                    .buttonStyle(CardPressButtonStyle())
                    if index < min(groupedByDay.count, 3) - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.sleepStroke, lineWidth: 1))
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
                    .fill(Color.sleepPurple.opacity(0.10)).frame(width: 44, height: 44)
                Image(systemName: "calendar").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.sleepPurpleDeep)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(dayTitle(group.day)).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.sleepInk)
                Text("\(group.items.filter { $0.kind != .break }.count) sessions")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.sleepMuted)
            }
            Spacer()
            HStack(spacing: 7) {
                Text(TimeFormat.minutes(totalMinutes(for: group.items)))
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.sleepInk)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sleepPurpleDeep)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
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
        self.onSave  = onSave
        _selectedTime = State(initialValue: initialTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.sleepSun.opacity(0.12)).frame(width: 58, height: 58)
                    Image(systemName: "sunrise.fill").font(.system(size: 27, weight: .semibold)).foregroundStyle(Color.sleepSun)
                }
                VStack(spacing: 6) {
                    Text("When did your baby wake up?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.sleepInk).multilineTextAlignment(.center)
                    Text("This time becomes the starting point for today's sleep predictions.")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.sleepMuted)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                DatePicker("Wake-up time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150).clipped()
                Spacer()
            }
            .padding(.top, 24)
            .background(Color.sleepBackground)
            .navigationTitle("Today's Wake-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave(selectedTime); dismiss() }.fontWeight(.semibold)
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
            let w = proxy.size.width; let h = proxy.size.height; let s = min(w, h)
            ZStack {
                Image(systemName: "star.fill").font(.system(size: s * 0.16, weight: .semibold))
                    .foregroundStyle(Color.sleepSun.opacity(0.85)).position(x: w * 0.88, y: h * 0.20)
                Image(systemName: "sparkle").font(.system(size: s * 0.13, weight: .bold))
                    .foregroundStyle(Color.sleepPurple.opacity(0.55)).position(x: w * 0.12, y: h * 0.32)
                Image(systemName: "moon.fill").font(.system(size: s * 0.78))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.white.opacity(0.84), Color.sleepLilac, Color.sleepPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .rotationEffect(.degrees(-12))
                    .shadow(color: Color.sleepPurple.opacity(0.18), radius: s * 0.10, x: 0, y: s * 0.06)
                    .position(x: w * 0.56, y: h * 0.43)
                HStack(spacing: -s * 0.08) {
                    Circle().fill(Color.white.opacity(0.88)).frame(width: s * 0.28, height: s * 0.28)
                    Circle().fill(Color.white.opacity(0.94)).frame(width: s * 0.38, height: s * 0.38)
                    Circle().fill(Color.white.opacity(0.88)).frame(width: s * 0.28, height: s * 0.28)
                }.position(x: w * 0.57, y: h * 0.78)
                VStack(spacing: s * 0.025) {
                    HStack(spacing: s * 0.14) {
                        SleepArcEye().frame(width: s * 0.13, height: s * 0.08)
                        SleepArcEye().frame(width: s * 0.13, height: s * 0.08)
                    }
                    SleepSmile().stroke(Color.sleepPurpleDeep, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .frame(width: s * 0.20, height: s * 0.10)
                }.position(x: w * 0.55, y: h * 0.50)
            }
            .frame(width: w, height: h)
        }
    }
}

private struct SleepFaceProgress: View {
    let progress: Double
    private let ringWidth: CGFloat = 10
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.2).frame(width: side * 1.22, height: side * 1.22)
                Circle().inset(by: ringWidth / 2).stroke(Color.white.opacity(0.22), lineWidth: ringWidth)
                Circle().inset(by: ringWidth / 2).trim(from: 0, to: progress)
                    .stroke(Color.sleepPurpleDeep, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-88))
                Circle().fill(Color.white.opacity(0.78)).padding(side * 0.24)
                VStack(spacing: side * 0.055) {
                    HStack(spacing: side * 0.15) {
                        SleepArcEye().frame(width: side * 0.13, height: side * 0.08)
                        SleepArcEye().frame(width: side * 0.13, height: side * 0.08)
                    }
                    SleepSmile().stroke(Color.sleepPurpleDeep, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: side * 0.24, height: side * 0.13)
                }
                HStack(spacing: side * 0.45) {
                    Circle().fill(Color.pink.opacity(0.20)).frame(width: side * 0.13, height: side * 0.13)
                    Circle().fill(Color.pink.opacity(0.20)).frame(width: side * 0.13, height: side * 0.13)
                }.offset(y: side * 0.14)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .shadow(color: Color.sleepInk.opacity(0.08), radius: 8, x: 0, y: 6)
    }
}

private struct SleepArcEye: View {
    var body: some View {
        ArcShape().stroke(Color.sleepPurpleDeep, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
}

private struct SleepSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

// MARK: - Colors

private extension Color {
    static let sleepBackground = Color(hex: 0xFBFAFF)
    static let sleepInk        = Color(hex: 0x090A33)
    static let sleepMuted      = Color(hex: 0x686A82)
    static let sleepPurple     = Color(hex: 0x8A73F6)
    static let sleepPurpleDeep = Color(hex: 0x6549E6)
    static let sleepLilac      = Color(hex: 0xBCA7FF)
    static let sleepSun        = Color(hex: 0xFDBB32)
    static let sleepCloud      = Color(hex: 0xBBA8FA)
    static let sleepGreen      = Color(hex: 0x1F9B6D)
    static let sleepStroke     = Color(hex: 0xECE9F6)
    static let sleepWarmCard   = Color(hex: 0xFFF9F2)

    init(hex: Int, opacity: Double = 1) {
        self.init(.sRGB,
                  red:     Double((hex >> 16) & 0xff) / 255,
                  green:   Double((hex >>  8) & 0xff) / 255,
                  blue:    Double( hex         & 0xff) / 255,
                  opacity: opacity)
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
