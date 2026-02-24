import SwiftUI

struct DayDetailView: View {
    let day: Date
    let records: [SleepRecord]
    let onDelete: (_ ids: Set<UUID>) -> Void
    let onAddTap: () -> Void

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
                    Button { onAddTap() } label: { Image(systemName: "plus") }
                }
            }
        }
    }


    private var recordsSection: some View {
        Section {
            let sorted = records.sorted { $0.date < $1.date } // en erken = 1. Nap

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, record in
                NapRow(
                    napNumber: index + 1,
                    record: record
                )
            }
            .onDelete(perform: delete)
        }
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }

    private var totalText: String {
        let total = records.map { $0.duration }.reduce(0, +)
        let h = total / 60
        let m = total % 60
        return "\(h)h \(m)m"
    }

    private func delete(at offsets: IndexSet) {
        // List'te sıralı gösteriyoruz; delete de aynı sırayla gitmeli
        let sorted = records.sorted { $0.date < $1.date }
        let ids = Set(offsets.map { sorted[$0].id })
        onDelete(ids)
    }
}

struct NapRow: View {
    let napNumber: Int
    let record: SleepRecord

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
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var napPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 11))
                .symbolRenderingMode(.hierarchical)

            Text("\(napNumber). Nap")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.indigo)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.indigo.opacity(0.12))
        )
    }
}
