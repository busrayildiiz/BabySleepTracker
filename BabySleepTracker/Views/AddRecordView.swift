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
            }.onAppear {
                // Night Sleep ile açılıyorsa ve user end’i elle oynamadıysa default 8h uygula
                if vm.kind == .nightSleep, !endManuallyEdited {
                    applyDefaultEndFromStart()
                }
            }
            .onChange(of: vm.kind) { _ in
                // kind değişince default end ayarla (user end’i elle değiştirmediyse)
                if !endManuallyEdited {
                    applyDefaultEndFromStart()
                }
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
                // Date değişince start/end combine zaten değişiyor; edge-case’leri toparla
                validateTimesAfterStartChange()
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
            VStack(alignment: .leading, spacing: 6) {
                VStack(spacing: 0) {
                    VStack() {
                        kindSelector
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                // ✅ DATE (separate row)
                row {
                    Text("Date")
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
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                }

                Divider().padding(.leading, 16)

                // START
                row {
                    Text("Start")
                    Spacer()
                    DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_US"))
                }

                Divider().padding(.leading, 16)

                // END
                row {
                    Text("End")
                    Spacer()
                    DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_US"))
                }

                Divider().padding(.leading, 16)

                // DURATION
                row {
                    Text("Duration")
                        .foregroundStyle(.secondary)

                    Spacer()

                    if crossesMidnight {
                        Text("+1 day")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.indigo.opacity(0.12)))
                            .foregroundStyle(.indigo)
                            .padding(.trailing, 6)
                    }

                    Text(TimeFormat.minutes(durationMinutes))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(16)
        .background(Color(.systemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
    // MARK: - Save logic

    private func save() {
        let start = startDateTime
        let minutes = durationMinutes
        let newRecord = SleepRecord(date: start, duration: minutes, kind: vm.kind)
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
   
    private var kindSelector: some View {
        HStack(spacing: 0) {
            kindButton(.dayNap)
            kindButton(.nightSleep)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
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
}


