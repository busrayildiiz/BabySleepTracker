import Foundation

protocol SleepStoring {
    func load() throws -> [SleepRecord]
    func save(_ records: [SleepRecord]) throws
}

enum SleepStoreError: Error {
    case decodingFailed
    case encodingFailed
}

final class SleepStore: SleepStoring {
    private let key = "sleep_records_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [SleepRecord] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([SleepRecord].self, from: data)
        } catch {
            throw SleepStoreError.decodingFailed
        }
    }

    func save(_ records: [SleepRecord]) throws {
        do {
            let data = try JSONEncoder().encode(records)
            defaults.set(data, forKey: key)
        } catch {
            throw SleepStoreError.encodingFailed
        }
    }
}
