import Foundation

protocol SleepAPI {
    func fetchRecords() async throws -> [SleepRecord]
}

struct MockSleepAPI: SleepAPI {
    func fetchRecords() async throws -> [SleepRecord] {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return [
            SleepRecord(id: UUID(), date: Date(), duration: 90),
            SleepRecord(id: UUID(), date: Date().addingTimeInterval(-86400), duration: 120)
        ]
    }
}
