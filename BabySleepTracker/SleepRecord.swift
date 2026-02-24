//
//  SleepRecord.swift
//  SleepTracker
//
//  Created by MacBook on 24.02.2026.
//

import Foundation

struct SleepRecord: Identifiable, Codable {
    let id : UUID
    let date: Date
    let duration: Int
    let kind: SleepKind

    init(id: UUID = UUID(), date: Date, duration: Int, kind: SleepKind = .dayNap) {
           self.id = id
           self.date = date
           self.duration = duration
           self.kind = kind
       }
    
    var formattedDuration : String {
        let hours = duration / 60
        let minutes = duration % 60
    return "\(hours) h \(minutes)m"
    }
    
    var displayDate : String {
        let calender = Calendar.current

        if calender.isDateInToday(date){
            return "Bugün"
        }else if calender.isDateInYesterday(date){
            return "Dün"
        }else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

enum SleepKind: String, Codable, CaseIterable, Identifiable {
    case dayNap
    case nightSleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dayNap: return "Day Nap"
        case .nightSleep: return "Night Sleep"
        }
    }

    var icon: String {
        switch self {
        case .dayNap: return "sun.max"
        case .nightSleep: return "moon.stars"
        }
    }
}
