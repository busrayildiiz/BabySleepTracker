//
//  SleepKind.swift
//  BabySleepTracker
//
//  Created by MacBook on 24.02.2026.
//

import Foundation

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
