import SwiftUI

struct AddRecordView: View {

    let defaultDate: Date
    let onSave: (SleepRecord) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var endTime: Date

    init(defaultDate: Date, onSave: @escaping (SleepRecord) -> Void) {
        self.defaultDate = defaultDate
        self.onSave = onSave

        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: defaultDate))
        _startTime = State(initialValue: defaultDate)
        _endTime = State(initialValue: defaultDate.addingTimeInterval(60 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timeCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Nap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(durationMinutes <= 0)
                }
            }
        }
        .tint(.indigo)
    }

    // MARK: - Cards

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(TimeFormat.ampm(startDateTime)) → \(TimeFormat.ampm(endDateTime))")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(selectedDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(TimeFormat.minutes(durationMinutes))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep time")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                row {
                    Text("Date")
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Divider().padding(.leading, 16)

                row {
                    Text("Start")
                    Spacer()
                    DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_US"))
                }

                Divider().padding(.leading, 16)

                row {
                    Text("End")
                    Spacer()
                    DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_US"))
                }

                Divider().padding(.leading, 16)

                row {
                    Text("Duration")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TimeFormat.minutes(durationMinutes))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func row(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .font(.body)
        .foregroundStyle(.primary)
    }

    // MARK: - Save logic

    private func save() {
        let start = startDateTime
        let minutes = durationMinutes
        let newRecord = SleepRecord(date: start, duration: minutes)
        onSave(newRecord)
        dismiss()
    }

    private func combine(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = d.year
        merged.month = d.month
        merged.day = d.day
        merged.hour = t.hour
        merged.minute = t.minute
        return cal.date(from: merged) ?? date
    }

    private var startDateTime: Date {
        combine(date: selectedDate, time: startTime)
    }

    private var endDateTime: Date {
        var end = combine(date: selectedDate, time: endTime)
        if end < startDateTime {
            end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return end
    }

    private var durationMinutes: Int {
        max(0, Int(endDateTime.timeIntervalSince(startDateTime) / 60))
    }
}
