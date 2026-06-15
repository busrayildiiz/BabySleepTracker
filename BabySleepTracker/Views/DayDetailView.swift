import SwiftUI

enum AddMode {
    case sleep
    case `break`
}

struct DayDetailView: View {
    let day: Date
    var records: [SleepRecord]

    let onDelete: (_ ids: Set<UUID>) -> Void
    let onAddSleep: (_ day: Date) -> Void
    let onEditNap: (_ nap: SleepRecord) -> Void
    let onBreakSaved: (_ newBreak: SleepRecord) -> Void

    @State private var showAddMenu = false
    @State private var showAddBreak = false
    @State private var breakTargetNap: SleepRecord? = nil
    @State private var contextNap: SleepRecord? = nil
    @State private var showNapActions = false

    @Environment(\.dismiss) private var dismiss

    private var sortedNaps: [SleepRecord] {
        let dayNaps = records.filter { $0.kind == .dayNap }.sorted { $0.date < $1.date }
        let nightSleeps = records.filter { $0.kind == .nightSleep }.sorted { $0.date < $1.date }
        return dayNaps + nightSleeps
    }

    private var breaks: [SleepRecord] {
        records.filter { $0.kind == .break }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(sortedNaps.enumerated()), id: \.element.id) { index, nap in
                    let napBreaks = breaks.filter { $0.parentNapID == nap.id }.sorted { $0.date < $1.date }
                    let napNumber = nap.kind == .dayNap
                        ? sortedNaps.prefix(index + 1).filter { $0.kind == .dayNap }.count
                        : 0

                    NapDetailCard(
                        napNumber: napNumber,
                        nap: nap,
                        napBreaks: napBreaks,
                        allBreaks: breaks,
                        onAddBreakTap: {
                            breakTargetNap = nap
                            showAddBreak = true
                        },
                        onLongPress: {
                            contextNap = nap
                            showNapActions = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEditNap(nap)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete([nap.id])
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddMenu = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Add", isPresented: $showAddMenu, titleVisibility: .hidden) {
                Button("Add Nap") { onAddSleep(day) }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog(
                contextNap.map { $0.kind == .nightSleep ? "Night Sleep" : "Nap" } ?? "",
                isPresented: $showNapActions,
                titleVisibility: .visible
            ) {
                Button("Edit") {
                    if let nap = contextNap { onEditNap(nap) }
                }
                Button("Add Wake Period") {
                    breakTargetNap = contextNap
                    showAddBreak = true
                }
                Button("Delete", role: .destructive) {
                    if let nap = contextNap { onDelete([nap.id]) }
                }
                Button("Cancel", role: .cancel) { contextNap = nil }
            }
            .sheet(isPresented: $showAddBreak) {
                if let nap = breakTargetNap {
                    AddBreakView(
                        defaultDate: nap.date,
                        targetNapID: nap.id,
                        napDuration: nap.duration,
                        existingBreaks: breaks.filter { $0.parentNapID == nap.id },
                        onSave: { newBreak in
                            onBreakSaved(newBreak)
                        }
                    )
                }
            }
        }
        .tint(.indigo)
    }

    private var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - NapDetailCard

struct NapDetailCard: View {
    let napNumber: Int
    let nap: SleepRecord
    let napBreaks: [SleepRecord]
    let allBreaks: [SleepRecord]
    let onAddBreakTap: () -> Void
    let onLongPress: () -> Void

    @State private var breaksExpanded = true

    private var isNight: Bool { nap.kind == .nightSleep }

    private var napTint: Color {
        nap.isOngoing ? .indigo : (isNight ? .indigo : .orange)
    }

    private var netMinutes: Int { nap.totalMinutes(breaks: allBreaks) }
    private var napEnd: Date {
        nap.date.addingTimeInterval(TimeInterval(nap.effectiveDuration * 60))
    }
    private var title: String { isNight ? "Night Sleep" : "Day Nap" }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header row ─────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: nap.kind.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(napTint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(napTint)
                    Text("\(TimeFormat.ampm(nap.date)) – \(TimeFormat.ampm(napEnd))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if nap.isOngoing {
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            Text(TimeFormat.minutes(nap.effectiveDuration))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.indigo)
                        }
                        Text("In progress")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.indigo)
                    } else {
                        Text(TimeFormat.minutes(nap.duration))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Total Sleep Time")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLongPress()
            }

            Divider().padding(.horizontal, 14)

            // ── Stats row ──────────────────────────────────
            HStack(spacing: 0) {
                // Breaks count
                VStack(spacing: 4) {
                    Text("\(napBreaks.count)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Text("Breaks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                // Net sleep
                VStack(alignment: .trailing, spacing: 2) {
                    if nap.isOngoing {
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            Text(TimeFormat.minutes(netMinutes))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.indigo)
                        }
                        Text("Net Sleep")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(TimeFormat.minutes(netMinutes))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Net Sleep")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)

            // ── Breaks list (expandable) ───────────────────
            if !napBreaks.isEmpty {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 0) {
                    // Breaks header
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            breaksExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Breaks (Wake Periods)")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(napBreaks.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.indigo.opacity(0.10)))
                            Image(systemName: breaksExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if breaksExpanded {
                        ForEach(napBreaks) { br in
                            HStack {
                                Text(TimeFormat.ampm(br.date))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                                Spacer()
                                Text("\(br.duration) min")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            if br.id != napBreaks.last?.id {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
            }

            Divider().padding(.horizontal, 14)

            // ── Add Wake Period button ─────────────────────
            Button(action: onAddBreakTap) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Add Wake Period")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.indigo.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
