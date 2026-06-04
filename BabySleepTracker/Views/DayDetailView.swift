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
    let onBreakSaved: (_ newBreak: SleepRecord) -> Void

    @State private var showAddMenu = false
    @State private var selectedNapID: UUID? = nil
    @State private var contextNap: SleepRecord? = nil
    @State private var showNapActions = false
    @State private var showAddBreak = false
    @State private var breakTargetNapID: UUID? = nil

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
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(sortedNaps.enumerated()), id: \.element.id) { index, nap in
                        let napBreaks = breaks
                            .filter { $0.parentNapID == nap.id }
                            .sorted { $0.date < $1.date }

                        let napNumber = nap.kind == .dayNap
                            ? sortedNaps.prefix(index + 1).filter { $0.kind == .dayNap }.count
                            : 0

                        NapTimelineSection(
                            napNumber: napNumber,
                            nap: nap,
                            breaks: napBreaks,
                            allBreaks: breaks,
                            isSelected: selectedNapID == nap.id,
                            onNapTap: { selectedNapID = nap.id },
                            onLongPress: {
                                contextNap = nap
                                showNapActions = true
                            }
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
                Button("Add Nap") { onAddSleep(day) }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog(
                contextNap.map { $0.kind == .nightSleep ? "Night Sleep" : "Nap" } ?? "",
                isPresented: $showNapActions,
                titleVisibility: .visible
            ) {
                Button("Add Break") {
                    breakTargetNapID = contextNap?.id
                    showAddBreak = true
                }
                Button("Delete", role: .destructive) {
                    if let nap = contextNap {
                        onDelete([nap.id])
                    }
                }
                Button("Cancel", role: .cancel) { contextNap = nil }
            }
            // AddBreakView DayDetailView içinden açılıyor
            .sheet(isPresented: $showAddBreak) {
                AddBreakView(
                    defaultDate: day,
                    targetNapID: breakTargetNapID,
                    onSave: { newBreak in
                        onBreakSaved(newBreak)
                    }
                )
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
    let onLongPress: () -> Void

    private var isNight: Bool { nap.kind == .nightSleep }
    private var napTint: Color { isNight ? Color.indigo : Color.orange }
    private var netMinutes: Int { nap.totalMinutes(breaks: allBreaks) }
    private var napEnd: Date {
        nap.date.addingTimeInterval(TimeInterval(nap.duration * 60))
    }
    private var title: String {
        isNight ? "Night Sleep" : "\(napNumber). Nap"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {

                // Nap header — seçim highlight sadece bu row'da
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
                        Text(title)
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
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(14)
                .background(
                    isSelected
                        ? AnyView(
                            napTint.opacity(0.08)
                                .clipShape(
                                    RoundedCorners(
                                        tl: 18, tr: 18,
                                        bl: breaks.isEmpty ? 18 : 0,
                                        br: breaks.isEmpty ? 18 : 0
                                    )
                                )
                          )
                        : AnyView(Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture { onNapTap() }
                .onLongPressGesture(minimumDuration: 0.4) {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    onLongPress()
                }

                // Break'ler
                if !breaks.isEmpty {
                    ForEach(Array(breaks.enumerated()), id: \.element.id) { i, br in
                        // Connector — ikon merkezi: padding(14) + iconWidth(52)/2 = 40pt
                        HStack(spacing: 0) {
                            // Sol boşluk: 14(padding) + 52/2 - 1(çizgi yarısı) = 39
                            Color.clear.frame(width: 39)

                            VStack(spacing: 0) {
                                Circle()
                                    .fill(i == 0 ? napTint : Color.indigo.opacity(0.4))
                                    .frame(width: 7, height: 7)

                                if i == 0 {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [napTint, Color.indigo.opacity(0.5)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 2, height: 20)
                                } else {
                                    VStack(spacing: 3) {
                                        ForEach(0..<4, id: \.self) { _ in
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(Color.indigo.opacity(0.4))
                                                .frame(width: 2, height: 4)
                                        }
                                    }
                                    .frame(height: 20)
                                }

                                Circle()
                                    .strokeBorder(Color.indigo.opacity(0.5), lineWidth: 2)
                                    .background(Circle().fill(Color(.systemBackground)))
                                    .frame(width: 7, height: 7)
                            }
                            .frame(width: 2, alignment: .center)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)

                        BreakRowInCard(record: br)
                    }

                    Spacer().frame(height: 4)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

            // Info banner — sadece kartın altında, bir kez
            if !breaks.isEmpty {
                infoBanner.padding(.top, 10)
            }
        }
    }

    private var infoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.indigo.opacity(0.6))
            Text("Breaks are part of this nap. They don't affect your total nap duration.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.indigo.opacity(0.06))
        )
    }
}

// MARK: - BreakRowInCard

private struct BreakRowInCard: View {
    let record: SleepRecord

    private var end: Date {
        record.date.addingTimeInterval(TimeInterval(record.duration * 60))
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.indigo.opacity(0.10))
                    .frame(width: 52, height: 52)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .medium))
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
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - RoundedCorners (iOS 16 uyumlu köşe kontrolü)

private struct RoundedCorners: Shape {
    var tl: CGFloat = 0
    var tr: CGFloat = 0
    var bl: CGFloat = 0
    var br: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
