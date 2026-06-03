//
//  SegmentKind.swift
//  BabySleepTracker
//
//  Created by MacBook on 26.02.2026.
//

import Foundation

enum SegmentKind: String, Codable { case sleep, `break` }

struct SleepSegment: Identifiable, Codable {
    let id: UUID
    var kind: SegmentKind
    var start: Date
    var end: Date
}

struct SleepSession: Identifiable, Codable {
    let id: UUID
    var kind: SleepKind          // dayNap / nightSleep
    var startDate: Date          // session başlangıcı (gün)
    var segments: [SleepSegment] // sleep + break parçaları

    var totalSleepMinutes: Int {
            // 1. Tüm ".sleep" segmentlerinin brüt toplamı (Mola ile uzamış süre dahil)
            let sleepMinutes = segments
                .filter { $0.kind == .sleep }
                .map { max(0, Int($0.end.timeIntervalSince($0.start) / 60)) }
                .reduce(0, +)
            
            // 2. Tüm ".break" segmentlerinin toplamı
            let breakMinutes = segments
                .filter { $0.kind == .break }
                .map { max(0, Int($0.end.timeIntervalSince($0.start) / 60)) }
                .reduce(0, +)
            
            // 3. Brüt uykudan, molaları çıkararak net uyku süresini buluyoruz
            return max(0, sleepMinutes - breakMinutes)
        }
}
