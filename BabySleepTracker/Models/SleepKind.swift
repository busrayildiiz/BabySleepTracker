import SwiftUI

enum SleepKind: String, Codable, CaseIterable, Identifiable {
    case dayNap
    case nightSleep
    case `break`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dayNap: return "Day Nap"
        case .nightSleep: return "Night Sleep"
        case .break: return "Break"
            
        }
    }

    var icon: String {
        switch self {
        case .dayNap: return "sun.max.fill"
        case .nightSleep: return "moon.stars.fill"
        case .break: return "cup.and.saucer"

        }
    }

    // MARK: - UI Helpers

    var tintColor: Color {
        switch self {
        case .dayNap: return .orange
        case .nightSleep: return .indigo
        case .break: return .mint
        }
    }

    var backgroundColor: Color {
        tintColor.opacity(0.12)
    }

    var cardBackgroundColor: Color {
        switch self {
        case .dayNap:
            return Color(.secondarySystemGroupedBackground)
        case .nightSleep:
            return Color.indigo.opacity(0.06)
        case .break:
            return Color(.secondarySystemGroupedBackground)
        }
       
    }
}
