//
//  InsightAgent.swift
//  BabySleepTracker
//
//  Created by MacBook on 11.06.2026.
//

import Foundation

struct SleepInsightBundle {
    let headline: String             // Ana mesaj (ör. "Harika gün!")
    let coachTip: String             // Günün koçluk mesajı
    let alerts: [SleepAlert]         // Kritik uyarılar
    let weeklyPattern: String?       // 7+ günden sonra gelen haftalık yorum
    let progressMessage: String      // "X günde Y kez takip ettin" gibi
}

struct SleepAlert {
    let severity: AlertSeverity
    let message: String
    let actionTitle: String?
    let actionType: AlertAction?
}

enum AlertSeverity { case info, warning, critical }
enum AlertAction { case addWakeTime, addNap, addNightSleep }
