import SwiftUI

struct AddRecordView: View {

    let defaultDate: Date
    let onSave: (SleepRecord) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @ObservedObject var vm: AddRecordViewModel
    @State private var endManuallyEdited = false
    @State private var isProgrammaticChange = false

    init(defaultDate: Date, vm: AddRecordViewModel, onSave: @escaping (SleepRecord) -> Void) {
        self.defaultDate = defaultDate
        self.onSave = onSave
        self.vm = vm
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: defaultDate))
        _startTime = State(initialValue: defaultDate)
        _endTime = State(initialValue: defaultDate.addingTimeInterval(60 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ── Segmented kind selector (tam genişlik) ──
                    kindSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // ── Date / Time form grubu ──
                    formCard

                    // ── Summary ──
                    summaryCard
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Sleep Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(durationMinutes <= 0)
                }
            }
            .onAppear {
                if vm.kind == .nightSleep, !endManuallyEdited {
                    applyDefaultEndFromStart()
                }
            }
            .onChange(of: vm.kind) { _ in
                if !endManuallyEdited { applyDefaultEndFromStart() }
                validateTimesAfterStartChange()
            }
            .onChange(of: startTime) { _ in
                if isProgrammaticChange { return }
                validateTimesAfterStartChange()
            }
            .onChange(of: endTime) { _ in
                if isProgrammaticChange { return }
                endManuallyEdited = true
                validateTimesAfterEndChange()
            }
            .onChange(of: selectedDate) { _ in
                validateTimesAfterStartChange()
            }
        }
        .tint(.indigo)
    }

    // MARK: - Kind Selector (Segmented, tam genişlik)

    private var kindSelector: some View {
        HStack(spacing: 0) {
            kindButton(.dayNap)
            kindButton(.nightSleep)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func kindButton(_ kind: SleepKind) -> some View {
        let isSelected = vm.kind == kind
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { vm.kind = kind }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(kind.title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.indigo : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Form Card (Date / Start / End)

    private var formCard: some View {
        VStack(spacing: 0) {
            // Date
            formRow {
                Label("Date", systemImage: "calendar")
                    .foregroundStyle(.primary)
                Spacer()
                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_US"))
            }

            if vm.kind == .nightSleep {
                Text("The selected date is the sleep start date.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            formDivider

            // Start Time
            formRow {
                Label("Start Time", systemImage: "clock")
                    .foregroundStyle(.primary)
                Spacer()
                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_US"))
            }

            formDivider

            // End Time
            formRow {
                Label("End Time", systemImage: "clock.badge.checkmark")
                    .foregroundStyle(.primary)
                Spacer()
                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_US"))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            formRow {
                Text("Total Duration")
                    .foregroundStyle(.primary)
                Spacer()

                if crossesMidnight {
                    Text("+1 day")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.indigo.opacity(0.12)))
                        .foregroundStyle(.indigo)
                        .padding(.trailing, 4)
                }

                Text(TimeFormat.minutes(durationMinutes))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(durationMinutes > 0 ? .primary : .secondary)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var formDivider: some View {
        Divider().padding(.leading, 16)
    }

    private func formRow(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .font(.body)
    }

    // MARK: - Logic (unchanged)

    private var defaultEndMinutes: Int {
        switch vm.kind {
        case .dayNap:     return 60
        case .nightSleep: return 8 * 60
        case .break:      return 15
        }
    }

    private var crossesMidnight: Bool {
        !Calendar.current.isDate(startDateTime, inSameDayAs: endDateTime)
    }

    private func applyDefaultEndFromStart() {
        isProgrammaticChange = true
        defer { isProgrammaticChange = false }
        if let newEnd = Calendar.current.date(byAdding: .minute, value: defaultEndMinutes, to: startTime) {
            endTime = newEnd
        }
    }

    private func validateTimesAfterStartChange() {
        if vm.kind == .dayNap, endDateTime <= startDateTime {
            applyDefaultEndFromStart()
        }
        if vm.kind == .nightSleep, durationMinutes <= 0, !endManuallyEdited {
            applyDefaultEndFromStart()
        }
    }

    private func validateTimesAfterEndChange() {
        if vm.kind == .dayNap, endDateTime <= startDateTime {
            applyDefaultEndFromStart()
        }
    }

    private func save() {
        let newRecord = SleepRecord(date: startDateTime, duration: durationMinutes, kind: vm.kind)
        onSave(newRecord)
        dismiss()
    }

    private func combine(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = d.year; merged.month = d.month; merged.day = d.day
        merged.hour = t.hour; merged.minute = t.minute
        return cal.date(from: merged) ?? date
    }

    private var startDateTime: Date { combine(date: selectedDate, time: startTime) }

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
