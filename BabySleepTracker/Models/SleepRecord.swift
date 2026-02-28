//
//  SleepRecord.swift
//  SleepTracker
//
//  Created by MacBook on 24.02.2026.
//

import Foundation

struct SleepRecord: Identifiable, Codable {
    let id: UUID
        let date: Date
        let duration: Int
        let kind: SleepKind
        let parentNapID: UUID?  

        init(
            id: UUID = UUID(),
            date: Date,
            duration: Int,
            kind: SleepKind = .dayNap,
            parentNapID: UUID? = nil
        ) {
            self.id = id
            self.date = date
            self.duration = duration
            self.kind = kind
            self.parentNapID = parentNapID
        }
    
    
    
    var formattedDuration : String {
        let hours = duration / 60
        let minutes = duration % 60
    return "\(hours) h \(minutes)m"
    }
    
    var displayDate : String {
        let calender = Calendar.current

        if calender.isDateInToday(date){
            return "Today"
        }else if calender.isDateInYesterday(date){
            return "Yesterday"
        }else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}


