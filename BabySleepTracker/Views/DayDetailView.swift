import SwiftUI

// ✅ Parent da erişsin diye dışarıda
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
                            Button {
                                showAddMenu = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
            .confirmationDialog(
                       "Add",
                       isPresented: $showAddMenu,
                       titleVisibility: .hidden
                   ) {
                       Button("Add Nap") {
                           onAddTap(.sleep, day, nil)
                       }

                       Button("Add Break") {
                           onAddTap(.break, day, nil)
                       }

                       Button("Cancel", role: .cancel) { }
                   }
        }
    }
    private var recordsSection: some View {
        let naps = records
            .filter { $0.kind == .dayNap || $0.kind == .nightSleep }
            .sorted { $0.date < $1.date }

        let breaks = records
            .filter { $0.kind == .break }
            .sorted { $0.date < $1.date }

        return Section {
            ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in

                // ✅ Nap satırı (seçilebilir)
                Button {
                    selectedNapID = nap.id
                } label: {
                    NapRow(napNumber: index + 1, record: nap)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedNapID == nap.id ? Color.indigo.opacity(0.8) : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

                // ✅ Bu nap'e bağlı break'ler
                let napBreaks = breaks.filter { $0.parentNapID == nap.id }

                if !napBreaks.isEmpty {
                    ForEach(napBreaks) { br in
                        BreakRow(record: br)
                            .padding(.leading, 12)  // içeri girsin
                    }
                }
            }
            .onDelete { offsets in
                // sadece nap’lerden sil
                let ids = Set(offsets.map { naps[$0].id })
                onDelete(ids)
            }
        }
    }

    private var addActionsSection: some View {
        Section {
            Button {
                onAddTap(.sleep, day, nil)
            } label: {
                AddActionRow(
                    title: "Add Nap",
                    subtitle: "Track a sleep session",
                    systemImage: "plus.circle.fill"
                )
            }

            Button {
                onAddTap(.break, day, selectedNapID)
            } label: {
                AddActionRow(
                    title: "Add Break",
                    subtitle: "Track a wake window / break",
                    systemImage: "cup.and.saucer.fill"
                )
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }

    private func delete(at offsets: IndexSet) {
        let sorted = records.sorted { $0.date < $1.date }

        var ids = Set<UUID>()
        for index in offsets {
            guard sorted.indices.contains(index) else { continue }
            ids.insert(sorted[index].id)
        }

        onDelete(ids)
    }
}

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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

struct NapRow: View {
    let napNumber: Int
    let record: SleepRecord

    private var isNight: Bool { record.kind == .nightSleep }
    private var isBreak: Bool { record.kind == .break }

    private var pillTint: Color {
        isNight ? .indigo : (isBreak ? .indigo : .orange)
    }
    private var pillBg: Color { pillTint.opacity(0.12) }

    private var cardBg: Color {
        if isNight { return Color.indigo.opacity(0.06) }
        return Color(.secondarySystemGroupedBackground)
    }

    private var end: Date {
        record.date.addingTimeInterval(TimeInterval(record.duration * 60))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            cardContent
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            napPill

            HStack(alignment: .firstTextBaseline) {
                Text("\(TimeFormat.ampm(record.date)) — \(TimeFormat.ampm(end))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(TimeFormat.minutes(record.duration))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var pillTitle: String {
        if isNight { return "Night" }
        if isBreak { return "Break" }
        return "\(napNumber). Nap"
    }

    private var napPill: some View {
        HStack(spacing: 6) {
            Image(systemName: record.kind.icon)
                .font(.system(size: 11))
                .symbolRenderingMode(.hierarchical)

            Text(pillTitle)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(pillTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(pillBg))
    }
}

struct BreakRow: View {
    let record: SleepRecord

    private var pillTint: Color { .indigo }
    private var pillBg: Color { pillTint.opacity(0.12) }
    private var cardBg: Color { Color(.secondarySystemGroupedBackground) }

    private var end: Date {
        record.date.addingTimeInterval(TimeInterval(record.duration * 60))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            cardContent
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            breakPill

            HStack(alignment: .firstTextBaseline) {
                Text("\(TimeFormat.ampm(record.date)) — \(TimeFormat.ampm(end))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(TimeFormat.minutes(record.duration))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var breakPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 11))
                .symbolRenderingMode(.hierarchical)

            Text("Break")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(pillTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(pillBg))
    }
}
