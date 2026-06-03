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
            List {
                recordsSection
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
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
    }

    // MARK: - Records Section

    private var recordsSection: some View {
        Section {
            ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in
                let napBreaks = breaks.filter { $0.parentNapID == nap.id }

                NapCard(
                    napNumber: index + 1,
                    nap: nap,
                    breaks: napBreaks,
                    allBreaks: breaks,
                    isSelected: selectedNapID == nap.id,
                    onTap: { selectedNapID = nap.id }
                )
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { naps[$0].id })
                onDelete(ids)
            }
        }
    }

    // MARK: - Helpers

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - NapCard

struct NapCard: View {
    let napNumber: Int
    let nap: SleepRecord
    let breaks: [SleepRecord]
    let allBreaks: [SleepRecord]
    let isSelected: Bool
    let onTap: () -> Void

    private var isNight: Bool { nap.kind == .nightSleep }

    private var tint: Color { isNight ? .indigo : .orange }

    private var cardBg: Color {
        isNight ? Color.indigo.opacity(0.06) : Color(.secondarySystemGroupedBackground)
    }

    private var napEnd: Date {
        nap.date.addingTimeInterval(TimeInterval(nap.duration * 60))
    }

    private var netMinutes: Int {
        nap.totalMinutes(breaks: allBreaks)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Nap Header Row ──────────────────────────────
                HStack(spacing: 12) {
                    // İkon
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: nap.kind.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                    // Başlık + net süre alt satır
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isNight ? "Night Sleep" : "\(napNumber). Nap")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("\(TimeFormat.ampm(nap.date)) — \(TimeFormat.ampm(napEnd))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()

                    // Sağ taraf: toplam süre + net süre
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeFormat.minutes(nap.duration))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if !breaks.isEmpty {
                            Text("\(TimeFormat.minutes(netMinutes)) net")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

     
                if !breaks.isEmpty {
                    
                    Divider()
                        .padding(.leading, 14)

                    ForEach(Array(breaks.enumerated()), id: \.element.id) { i, br in
                        BreakRowInline(record: br)

                        if i < breaks.count - 1 {
                            Divider()
                                .padding(.leading, 62) 
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? tint.opacity(0.8) : Color.primary.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BreakRowInline

private struct BreakRowInline: View {
    let record: SleepRecord

    private var end: Date {
        record.date.addingTimeInterval(TimeInterval(record.duration * 60))
    }

    var body: some View {
        HStack(spacing: 12) {
           
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "eye")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Awake Break")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text("\(TimeFormat.ampm(record.date)) — \(TimeFormat.ampm(end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Text(TimeFormat.minutes(record.duration))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - AddActionRow (unchanged)

private struct AddActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
