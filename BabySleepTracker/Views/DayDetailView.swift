import SwiftUI

enum AddMode {
    case sleep
    case `break`
}

struct DayDetailView: View {
    let day: Date
    let records: [SleepRecord]

    let onDelete: (_ ids: Set<UUID>) -> Void
    let onAddTap: (_ mode: AddMode, _ day: Date, _ targetNapID: UUID?) -> Void

    @State private var showAddMenu = false
    @State private var selectedNapID: UUID? = nil

    @Environment(\.dismiss) private var dismiss

    private var naps: [SleepRecord] {
        records
            .filter { $0.kind == .dayNap || $0.kind == .nightSleep }
            .sorted { $0.date < $1.date }
    }

    private var breaks: [SleepRecord] {
        records
            .filter { $0.kind == .break }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in
                        let napBreaks = breaks
                            .filter { $0.parentNapID == nap.id }
                            .sorted { $0.date < $1.date }

                        NapTimelineSection(
                            napNumber: index + 1,
                            nap: nap,
                            breaks: napBreaks,
                            allBreaks: breaks,
                            isSelected: selectedNapID == nap.id,
                            onNapTap: { selectedNapID = nap.id }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
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
                Button("Add Nap") { onAddTap(.sleep, day, nil) }
                Button("Add Break") { onAddTap(.break, day, nil) }
                Button("Cancel", role: .cancel) { }
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

// MARK: - NapTimelineSection

struct NapTimelineSection: View {
    let napNumber: Int
    let nap: SleepRecord
    let breaks: [SleepRecord]
    let allBreaks: [SleepRecord]
    let isSelected: Bool
    let onNapTap: () -> Void

    private var isNight: Bool { nap.kind == .nightSleep }
    private var napTint: Color { isNight ? Color.indigo : Color.orange }
    private var napBg: Color { napTint.opacity(0.10) }

    private var netMinutes: Int { nap.totalMinutes(breaks: allBreaks) }

    private var napEnd: Date {
        nap.date.addingTimeInterval(TimeInterval(nap.duration * 60))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Nap Card ──
            Button(action: onNapTap) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(napTint.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: nap.kind.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(napTint)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isNight ? "Night Sleep" : "\(napNumber). Nap")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if !breaks.isEmpty {
                            Text("\(TimeFormat.minutes(netMinutes)) net sleep")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(TimeFormat.ampm(nap.date)) — \(TimeFormat.ampm(napEnd))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(TimeFormat.minutes(nap.duration))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(napBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isSelected ? napTint.opacity(0.7) : Color.primary.opacity(0.06),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)

            // ── Break'ler varsa timeline ──
            if !breaks.isEmpty {
                ForEach(Array(breaks.enumerated()), id: \.element.id) { i, br in
                    TimelineConnector(
                        topColor: i == 0 ? napTint : Color.indigo.opacity(0.5),
                        bottomColor: Color.indigo.opacity(0.5),
                        isDashed: i > 0
                    )
                    BreakCard(record: br)
                }

                infoBanner
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 20)
    }

    private var infoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(.indigo.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text("Breaks are part of this nap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("They don't affect your total nap duration.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.indigo.opacity(0.06))
        )
    }
}

// MARK: - TimelineConnector

private struct TimelineConnector: View {
    let topColor: Color
    let bottomColor: Color
    var isDashed: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // İkon merkezine hizalı: padding(14) + icon(52)/2 = 40
            Spacer().frame(width: 40)

            VStack(spacing: 0) {
                Circle()
                    .fill(topColor)
                    .frame(width: 8, height: 8)

                if isDashed {
                    VStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(bottomColor)
                                .frame(width: 2, height: 4)
                        }
                    }
                    .frame(height: 32)
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [topColor, bottomColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 32)
                }

                Circle()
                    .strokeBorder(bottomColor, lineWidth: 2)
                    .background(Circle().fill(Color(.systemGroupedBackground)))
                    .frame(width: 8, height: 8)
            }

            Spacer()
        }
    }
}

// MARK: - BreakCard

private struct BreakCard: View {
    let record: SleepRecord

    private var end: Date {
        record.date.addingTimeInterval(TimeInterval(record.duration * 60))
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Break")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(TimeFormat.ampm(record.date)) – \(TimeFormat.ampm(end))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 6) {
                Text(TimeFormat.minutes(record.duration))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
