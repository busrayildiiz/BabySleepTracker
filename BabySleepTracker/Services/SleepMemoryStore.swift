import Foundation

/// Merkezi depolama yöneticisi - tüm UserDefaults çağrıları buradan geçer
final class SleepMemoryStore {
    static let shared = SleepMemoryStore()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Storage Keys
    private enum Keys: String {
        case sleepRecords = "sleepRecords"
        case dailyWakeRecords = "dailyWakeRecords_v1"
        case sleepCoachSnapshot = "sleepCoachSnapshot_v1"
        case babyName = "babyName"
        case babyBirthDate = "babyBirthDate"
        case avatarImageData = "avatarImageData"
        case overtiredLevel = "overtiredLevel"
        case nightPrediction = "nightPrediction"
        case currentPhase = "currentPhase"
    }
    
    // MARK: - Sleep Records
    
    func loadSleepRecords() -> [SleepRecord] {
        guard let data = defaults.data(forKey: Keys.sleepRecords.rawValue),
              let records = try? JSONDecoder().decode([SleepRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    func saveSleepRecords(_ records: [SleepRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Keys.sleepRecords.rawValue)
            NotificationCenter.default.post(name: NSNotification.Name("sleepRecordsDidChange"), object: nil)
        }
    }
    
    // MARK: - Daily Wake Records
    
    func loadDailyWakeRecords() -> [DailyWakeRecord] {
        guard let data = defaults.data(forKey: Keys.dailyWakeRecords.rawValue),
              let records = try? JSONDecoder().decode([DailyWakeRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    func saveDailyWakeRecords(_ records: [DailyWakeRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Keys.dailyWakeRecords.rawValue)
            NotificationCenter.default.post(name: NSNotification.Name("dailyWakeRecordsDidChange"), object: nil)
        }
    }
    
    // MARK: - Sleep Coach Snapshot
    
    func loadSleepCoachSnapshot() -> SleepCoachSnapshot? {
        guard let data = defaults.data(forKey: Keys.sleepCoachSnapshot.rawValue),
              let snapshot = try? JSONDecoder().decode(SleepCoachSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
    
    func saveSleepCoachSnapshot(_ snapshot: SleepCoachSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Keys.sleepCoachSnapshot.rawValue)
        }
    }
    
    // MARK: - Baby Info
    
    func getBabyName() -> String {
        let value = defaults.string(forKey: Keys.babyName.rawValue)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Baby" : value
    }
    
    func setBabyName(_ name: String) {
        defaults.set(name, forKey: Keys.babyName.rawValue)
    }
    
    func getBabyBirthDate() -> Date? {
        if let savedDate = defaults.object(forKey: Keys.babyBirthDate.rawValue) as? Date {
            return savedDate
        } else if let seconds = defaults.object(forKey: Keys.babyBirthDate.rawValue) as? Double {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
    
    func setBabyBirthDate(_ date: Date) {
        defaults.set(date, forKey: Keys.babyBirthDate.rawValue)
    }
    
    // MARK: - Avatar Image
    
    func loadAvatarImage() -> UIImage? {
        guard let data = defaults.data(forKey: Keys.avatarImageData.rawValue) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func saveAvatarImage(_ imageData: Data) {
        defaults.set(imageData, forKey: Keys.avatarImageData.rawValue)
    }
    
    // MARK: - Overtired Level
    
    func getOvertiredLevel() -> Double {
        return defaults.double(forKey: Keys.overtiredLevel.rawValue)
    }
    
    func setOvertiredLevel(_ level: Double) {
        defaults.set(level, forKey: Keys.overtiredLevel.rawValue)
    }
    
    // MARK: - Night Prediction
    
    func loadNightPrediction() -> NightPrediction? {
        guard let data = defaults.data(forKey: Keys.nightPrediction.rawValue),
              let prediction = try? JSONDecoder().decode(NightPrediction.self, from: data) else {
            return nil
        }
        return prediction
    }
    
    func saveNightPrediction(_ prediction: NightPrediction) {
        if let data = try? JSONEncoder().encode(prediction) {
            defaults.set(data, forKey: Keys.nightPrediction.rawValue)
        }
    }
    
    // MARK: - Current Phase
    
    func getCurrentPhase() -> SleepCoachMode {
        if let data = defaults.data(forKey: Keys.currentPhase.rawValue),
           let phase = try? JSONDecoder().decode(SleepCoachMode.self, from: data) {
            return phase
        }
        return .baseline
    }
    
    func setCurrentPhase(_ phase: SleepCoachMode) {
        if let data = try? JSONEncoder().encode(phase) {
            defaults.set(data, forKey: Keys.currentPhase.rawValue)
        }
    }
}

// MARK: - NightPrediction Model
struct NightPrediction: Codable {
    let predictedBedtime: Date
    let expectedDuration: TimeInterval
    let confidence: Double
    let recommendedWakeup: Date
}
