import SwiftUI

struct AddBreakView: View {
    let defaultDate: Date
    let onSave: (SleepRecord) -> Void
    let targetNapID: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var duration: Int = 10 // dakika

    init(defaultDate: Date,
         targetNapID: UUID?,
         onSave: @escaping (SleepRecord) -> Void)
    {
        self.defaultDate = defaultDate
        self.targetNapID = targetNapID 
        self.onSave = onSave
        _date = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date)
                }

                Section("Duration") {
                    Stepper(value: $duration, in: 1...180, step: 1) {
                        Text("\(duration) min")
                    }
                }
            }
            .navigationTitle("Add Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let record = SleepRecord(
                          date: date,
                          duration: duration,
                          kind: .break,
                          parentNapID: targetNapID
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(duration <= 0)
                }
            }
        }
    }
}
