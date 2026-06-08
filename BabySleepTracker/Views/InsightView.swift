//
//  InsightView.swift
//  BabySleepTracker
//
//  Created by MacBook on 6.06.2026.
//

import Foundation
import SwiftUI
import Charts

struct InsightsView: View {

    @State private var records: [SleepRecord] = []
    @State private var animateChart = false
    @AppStorage("babyName") private var babyName: String = "Baby"

    private let calendar = Calendar.current

    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: "sleepRecords"),
           let decoded = try? JSONDecoder().decode([SleepRecord].self, from: data) {
            records = decoded
        }
    }

    // MARK: - Computed stats

    private var napsOnly: [SleepRecord] {
        records.filter { $0.kind != .break }
    }

    private var breaksOnly: [SleepRecord] {
        records.filter { $0.kind == .break }
    }

    private func netMinutes(_ nap: SleepRecord) -> Int {
        nap.totalMinutes(breaks: breaksOnly)
    }

    // Bu haftaki günlük ortalama
    private var weeklyAverageNap: Int {
        let sevenAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let thisWeek = napsOnly.filter { $0.date >= sevenAgo }
        guard !thisWeek.isEmpty else { return 0 }
        let total = thisWeek.reduce(0) { $0 + netMinutes($1) }
        return total / max(1, Set(thisWeek.map { calendar.startOfDay(for: $0.date) }).count)
    }

    // Consistency: son 7 günde kaç gün kayıt var
    private var consistencyPercent: Int {
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
        let active = days.filter { day in
            napsOnly.contains { calendar.isDate($0.date, inSameDayAs: day) }
        }.count
        return Int(Double(active) / 7.0 * 100)
    }

    private var consistencyLabel: String {
        switch consistencyPercent {
        case 86...100: return "Excellent"
        case 57...85:  return "Good"
        case 29...56:  return "Fair"
        default:       return "Low"
        }
    }

    // En uzun nap
    private var longestNap: SleepRecord? {
        napsOnly.max { netMinutes($0) < netMinutes($1) }
    }

    private var longestNapDate: String {
        guard let n = longestNap else { return "–" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d"
        return f.string(from: n.date)
    }

    // Son 30 gün günlük toplam (chart için)
    struct DailySleep: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int
    }

    private var last30Days: [DailySleep] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayNaps = napsOnly.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let total = dayNaps.reduce(0) { $0 + netMinutes($1) }
            return DailySleep(date: day, minutes: total)
        }
    }

    private var chartMax: Int {
        let maxVal = last30Days.map { $0.minutes }.max() ?? 60
        return max(120, Int(ceil(Double(maxVal) / 60.0)) * 60)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    statsCards
                    observationCard
                    patternAndTrendCards
                    durationChartCard
                    feedingConnectionCard
                    sleepCoachCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                loadRecords()
                animateChart = false
                withAnimation(.easeOut(duration: 0.8)) { animateChart = true }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Insights")
                        .font(.largeTitle.weight(.bold))
                    Text("✨")
                }
                HStack(spacing: 4) {
                    Text("Understand \(babyName)'s sleep better")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("💜")
                }
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                Image(systemName: "info")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.indigo)
            }
        }
    }

    // MARK: - Stats Cards (3'lü grid)

    private var statsCards: some View {
        HStack(spacing: 10) {
            // Average Nap
            statCard(
                icon: "sun.max.fill",
                iconColor: .orange,
                label: "Average Nap",
                value: weeklyAverageNap > 0 ? TimeFormat.minutes(weeklyAverageNap) : "–",
                sub: "This Week",
                decoration: AnyView(miniLineDecoration),
                accentColor: .orange
            )

            // Consistency
            statCard(
                icon: "leaf.fill",
                iconColor: .green,
                label: "Consistency",
                value: napsOnly.isEmpty ? "–" : consistencyLabel,
                sub: "\(consistencyPercent)%",
                decoration: AnyView(
                    Image(systemName: "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(.pink.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                ),
                accentColor: .green
            )

            // Longest Nap
            statCard(
                icon: "moon.fill",
                iconColor: .indigo,
                label: "Longest Nap",
                value: longestNap != nil ? TimeFormat.minutes(netMinutes(longestNap!)) : "–",
                sub: longestNapDate,
                decoration: AnyView(
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                ),
                accentColor: .indigo
            )
        }
    }

    private func statCard(icon: String, iconColor: Color, label: String,
                          value: String, sub: String,
                          decoration: AnyView, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(accentColor)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(sub)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
            decoration
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // Mini line decoration for Average Nap card
    private var miniLineDecoration: some View {
        GeometryReader { geo in
            let data = last30Days.suffix(10).map { $0.minutes }
            let maxVal = CGFloat(data.max() ?? 1)
            let points = data.enumerated().map { (i, val) -> CGPoint in
                let x = geo.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                let y = geo.size.height * (1 - CGFloat(val) / maxVal)
                return CGPoint(x: x, y: y)
            }
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(Color.indigo.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 28)
    }

    // MARK: - Observation Card

    private var observationCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.07))

            Text("☁️")
                .font(.system(size: 60))
                .opacity(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Observation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Text("\(babyName) tends to sleep longer between 11 AM and 1 PM.")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Pattern & Trend Cards

    private var patternAndTrendCards: some View {
        HStack(spacing: 10) {
            // Pattern Found
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.indigo)
                    Text("Pattern Found")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Wake periods usually happen within the first 30 minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(.indigo.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )

            // Trend
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("Trend")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Average nap duration increased 12% compared to last week.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    // MARK: - Duration Chart

    private var durationChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Average Nap Duration")
                    .font(.headline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Text("Last 30 Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }

            Chart(last30Days) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Min", animateChart ? item.minutes : 0)
                )
                .cornerRadius(4)
                .foregroundStyle(Color.indigo.opacity(0.25))
            }
            .chartYScale(domain: 0...chartMax)
            .chartYAxis {
                AxisMarks(values: [0, chartMax / 2, chartMax]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.primary.opacity(0.07))
                    AxisValueLabel {
                        if let m = value.as(Int.self) {
                            Text("\(m / 60)h")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Feeding Connection (V2 placeholder)

    private var feedingConnectionCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Sleep & Feeding Connection")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Days with solid meals in the afternoon show 18% longer naps on average.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Sleep Coach (V2 AI placeholder)

    private var sleepCoachCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.pink)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Sleep Coach")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Based on last 14 days, \(babyName) seems ready for a nap around 12:15 PM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 6) {
                // V2 badge
                Text("V2")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.indigo))

                Text("🌟")
                    .font(.system(size: 22))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.indigo.opacity(0.15), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            // AI powered badge
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .semibold))
                Text("AI Powered")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.indigo)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.indigo.opacity(0.10))
            )
            .padding(10)
        }
    }
}
