import SwiftUI

struct SleepRecordRow: View {
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

    private var pillTitle: String {
        if isNight { return "Night" }
        if isBreak { return "Break" }
        return "\(napNumber). Nap"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
