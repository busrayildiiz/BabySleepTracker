import Foundation
import SwiftUI

@MainActor
final class AddRecordViewModel: ObservableObject {

    @Published var date: Date = Date()
    @Published var durationText: String = ""
    @Published var kind: SleepKind = .dayNap

    @Published var validationMessage: String?

    func buildRecord() -> SleepRecord? {

        let trimmed = durationText.trimmingCharacters(in: .whitespaces)

        guard let minutes = Int(trimmed),
              minutes > 0,
              minutes <= 24 * 60 else {
            validationMessage = "Duration must be between 1–1440 minutes."
            return nil
        }

        validationMessage = nil

        return SleepRecord(
            date: date,
            duration: minutes,
            kind: kind
        )
    }
}
