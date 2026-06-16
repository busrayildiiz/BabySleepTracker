//
//  Date+Extensions.swift
//  BabySleepTracker
//
//  Created by MacBook on 13.06.2026.
//

import Foundation

extension Date {
    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    func addingHours(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }
}
