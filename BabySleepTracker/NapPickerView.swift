import SwiftUI

struct NapPickerView: View {
    let naps: [SleepRecord]
    let onPick: (SleepRecord) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in
                    Button {
                        onPick(nap)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nap.kind == .nightSleep ? "Night Sleep" : "\(index + 1). Nap")
                                    .font(.headline)
                                Text(TimeFormat.ampm(nap.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(TimeFormat.minutes(nap.duration))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle("Select Nap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
