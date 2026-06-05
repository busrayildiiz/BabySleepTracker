import SwiftUI

struct AddBreakView: View {
    let defaultDate: Date
    let targetNapID: UUID?
    let napDuration: Int          // dakika — net sleep preview için
    let existingBreaks: [SleepRecord]
    let onSave: (SleepRecord) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var wakeTime: Date
    @State private var duration: Double = 5  // 1–20 dk

    init(
        defaultDate: Date,
        targetNapID: UUID?,
        napDuration: Int = 60,
        existingBreaks: [SleepRecord] = [],
        onSave: @escaping (SleepRecord) -> Void
    ) {
        self.defaultDate = defaultDate
        self.targetNapID = targetNapID
        self.napDuration = napDuration
        self.existingBreaks = existingBreaks
        self.onSave = onSave
        _wakeTime = State(initialValue: defaultDate)
    }

    // MARK: - Computed

    private var totalBreakMinutes: Int {
        existingBreaks.reduce(0) { $0 + $1.duration } + Int(duration)
    }

    private var netSleepMinutes: Int {
        max(0, napDuration - totalBreakMinutes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Wake Time ─────────────────────────
                    sectionCard(title: "Wake Time") {
                        VStack(spacing: 0) {
                            // Text display
                            HStack {
                                Text(TimeFormat.ampm(wakeTime))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                                Spacer()
                                Image(systemName: "clock")
                                    .foregroundStyle(.indigo)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            Divider()

                            // Scroll wheel picker
                            DatePicker("", selection: $wakeTime, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.wheel)
                                .environment(\.locale, Locale(identifier: "en_US"))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // ── Duration Slider ───────────────────
                    sectionCard(title: "Duration") {
                        VStack(spacing: 14) {
                            Text("\(Int(duration)) min")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.indigo)

                            Slider(value: $duration, in: 1...60, step: 1)
                                .tint(.indigo)
                                .padding(.horizontal, 4)

                            // Labels
                            HStack {
                                ForEach(["1 min", "5 min", "10 min", "15 min", "20 min"], id: \.self) { label in
                                    Text(label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if label != "20 min" { Spacer() }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }

                    // ── Net Sleep Preview ─────────────────
                    netSleepPreview

                    // ── Info Banner ───────────────────────
                    infoBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Wake Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let record = SleepRecord(
                            date: wakeTime,
                            duration: Int(duration),
                            kind: .break,
                            parentNapID: targetNapID
                        )
                        onSave(record)
                        dismiss()
                    } label: {
                        Text("Add Wake Period")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.indigo, in: Capsule())
                    }
                }
            }
        }
        .tint(.indigo)
    }

    // MARK: - Net Sleep Preview

    private var netSleepPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text("Net Sleep Preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            HStack(spacing: 0) {
                previewStat(label: "Total Sleep", value: TimeFormat.minutes(napDuration), color: .primary)
                Divider().frame(height: 36)
                previewStat(label: "Breaks", value: TimeFormat.minutes(totalBreakMinutes), color: .secondary)
                Divider().frame(height: 36)
                previewStat(label: "Net Sleep", value: TimeFormat.minutes(netSleepMinutes), color: .indigo)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.indigo.opacity(0.15), lineWidth: 1)
        )
    }

    private func previewStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(.indigo.opacity(0.7))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("What is a Wake Period?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("A wake period (break) is when your baby wakes up during a nap. It will be subtracted from the total sleep time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("😴")
                .font(.system(size: 32))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.indigo.opacity(0.06))
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
