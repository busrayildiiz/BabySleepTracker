//
//  DayDetailViewModel.swift
//  BabySleepTracker
//
//  Created by MacBook on 25.02.2026.
//

import Foundation

struct DayDetailViewModel {

    let records: [SleepRecord]

    var totalMinutes: Int {
        records.map(\.duration).reduce(0, +)
    }

    var formattedTotal: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours) h \(minutes)m"
    }
}
