//
//  NemuriDataReader.swift
//  Nami
//
//  Read sleep data from Nemuri app via App Group shared container
//  Nemuri writes JSON + UserDefaults; Nami reads for mood-sleep analysis
//

import Foundation
import os

private let logger = Logger(subsystem: "com.imai.Nami", category: "NemuriIntegration")

// MARK: - Sleep Record Model

/// A single sleep record from Nemuri (matches Nemuri's NamiSleepData structure)
struct NemuriSleepRecord: Codable, Identifiable {
    let bedtime: Date
    let wakeTime: Date
    let durationSeconds: Double
    let qualityScore: Double // 0-100
    let efficiency: Double // 0.0-1.0
    let sleepLatencyMinutes: Double
    let awakenings: Int
    let createdAt: Date

    var id: Date {
        createdAt
    }

    /// Sleep duration in hours
    var durationHours: Double {
        durationSeconds / 3600.0
    }

    /// Formatted duration string (e.g. "6h 45m")
    var formattedDuration: String {
        let hours = Int(durationSeconds) / 3600
        let minutes = (Int(durationSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    /// Formatted bedtime (e.g. "23:15")
    var formattedBedtime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: bedtime)
    }

    /// Formatted wake time (e.g. "06:45")
    var formattedWakeTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: wakeTime)
    }
}

/// Container for the JSON file Nemuri writes
struct NemuriSleepDataStore: Codable {
    let records: [NemuriSleepRecord]
    let lastUpdated: Date
}

// MARK: - Data Reader

/// Reads Nemuri sleep data from App Group shared container
enum NemuriDataReader {
    static let appGroupID = "group.com.imai.Nami"
    static let fileName = "nemuri_sleep_data.json"

    /// Whether Nemuri data is available (app installed and has recorded data)
    static var isAvailable: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }
        let lastUpdated = defaults.double(forKey: "nemuri_lastUpdated")
        guard lastUpdated > 0 else { return false }
        // Check freshness: within 7 days
        let lastDate = Date(timeIntervalSince1970: lastUpdated)
        return abs(lastDate.timeIntervalSinceNow) < 7 * 86400
    }

    // MARK: - Quick Access (UserDefaults)

    /// Read the latest sleep summary from App Group UserDefaults (lightweight)
    static func readLatestSleep() -> NemuriSleepRecord? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }

        let lastUpdated = defaults.double(forKey: "nemuri_lastUpdated")
        guard lastUpdated > 0 else { return nil }

        // Check freshness: within 48 hours
        let lastDate = Date(timeIntervalSince1970: lastUpdated)
        guard abs(lastDate.timeIntervalSinceNow) < 48 * 3600 else { return nil }

        let bedtime = Date(timeIntervalSince1970: defaults.double(forKey: "nemuri_bedtime"))
        let wakeTime = Date(timeIntervalSince1970: defaults.double(forKey: "nemuri_wakeTime"))
        let duration = defaults.double(forKey: "nemuri_duration")
        let quality = defaults.double(forKey: "nemuri_quality")
        let efficiency = defaults.double(forKey: "nemuri_efficiency")
        let latency = defaults.double(forKey: "nemuri_latency")

        guard duration > 0 else { return nil }

        return NemuriSleepRecord(
            bedtime: bedtime,
            wakeTime: wakeTime,
            durationSeconds: duration,
            qualityScore: quality,
            efficiency: efficiency,
            sleepLatencyMinutes: latency,
            awakenings: 0, // Not available in UserDefaults quick access
            createdAt: lastDate
        )
    }

    // MARK: - Full History (JSON file)

    /// Read all sleep records from JSON file (up to 90 days)
    static func readAllRecords() -> [NemuriSleepRecord] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return [] }

        let fileURL = containerURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            // Try ISO 8601 first (expected format), fall back to deferredToDate
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let store = try? decoder.decode(NemuriSleepDataStore.self, from: data) {
                return store.records.sorted { $0.createdAt > $1.createdAt }
            }
            // Fallback: Nemuri may have written with default (deferredToDate) encoding
            let fallbackDecoder = JSONDecoder()
            let store = try fallbackDecoder.decode(NemuriSleepDataStore.self, from: data)
            logger.info("Decoded Nemuri data using deferredToDate fallback")
            return store.records.sorted { $0.createdAt > $1.createdAt }
        } catch {
            logger.error("Failed to read Nemuri data: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Date Matching

    /// Match sleep records to mood entries by wake date
    /// Sleep on night of 3/26 → wake on 3/27 → matches mood entries on 3/27
    static func matchSleepToMood(
        sleepRecords: [NemuriSleepRecord],
        moodEntries: [MoodEntry]
    ) -> [(sleep: NemuriSleepRecord, mood: MoodEntry)] {
        let calendar = Calendar.current
        var results: [(NemuriSleepRecord, MoodEntry)] = []

        // Group mood entries by day
        let moodByDay = Dictionary(grouping: moodEntries) { calendar.startOfDay(for: $0.createdAt) }

        for sleep in sleepRecords {
            let wakeDay = calendar.startOfDay(for: sleep.wakeTime)
            // Match to first mood entry of that day
            if let dayEntries = moodByDay[wakeDay], let firstMood = dayEntries.first {
                results.append((sleep, firstMood))
            }
        }

        return results
    }

    // MARK: - Analysis Helpers

    /// Calculate average mood score for sleep records matching a condition
    static func averageMoodForSleep(
        where condition: (NemuriSleepRecord) -> Bool,
        sleepRecords: [NemuriSleepRecord],
        moodEntries: [MoodEntry]
    ) -> (average: Double, count: Int)? {
        let matched = matchSleepToMood(sleepRecords: sleepRecords, moodEntries: moodEntries)
        let filtered = matched.filter { condition($0.sleep) }
        guard filtered.count >= 3 else { return nil }

        let avg = filtered.map(\.mood.normalizedScore).reduce(0, +) / Double(filtered.count)
        return (avg, filtered.count)
    }
}

// MARK: - Nami → Nemuri (Reverse direction)

/// Writes Nami mood data to App Group for Nemuri to read
enum NamiDataWriter {
    static let appGroupID = "group.com.imai.Nami"
    static let fileName = "nami_mood_data.json"

    /// Latest mood data structure for Nemuri to read
    struct NamiMoodSummary: Codable {
        let latestMoodScore: Double
        let latestMoodDate: Date
        let latestMaxScore: Int
        let weeklyAverage: Double
        let weeklyCount: Int
        let lastUpdated: Date
    }

    /// Write latest mood data to App Group for Nemuri
    static func writeMoodData(latestEntry: MoodEntry, weeklyAvg: Double, weeklyCount: Int) {
        let summary = NamiMoodSummary(
            latestMoodScore: Double(latestEntry.score),
            latestMoodDate: latestEntry.createdAt,
            latestMaxScore: latestEntry.maxScore,
            weeklyAverage: weeklyAvg,
            weeklyCount: weeklyCount,
            lastUpdated: .now
        )

        // Write JSON file
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let fileURL = containerURL.appendingPathComponent(fileName)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to write Nami mood data: \(error.localizedDescription)")
        }

        // Write UserDefaults for quick access
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(Double(latestEntry.score), forKey: "nami_latestScore")
        defaults.set(latestEntry.createdAt.timeIntervalSince1970, forKey: "nami_latestDate")
        defaults.set(latestEntry.maxScore, forKey: "nami_maxScore")
        defaults.set(weeklyAvg, forKey: "nami_weeklyAverage")
        defaults.set(Date.now.timeIntervalSince1970, forKey: "nami_lastUpdated")
    }
}
