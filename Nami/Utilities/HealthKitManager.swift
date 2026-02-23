//
//  HealthKitManager.swift
//  Nami
//
//  HealthKit data fetching for steps, sleep, and active energy
//

import Foundation
import HealthKit
import SwiftUI

// MARK: - DailyHealthData

struct DailyHealthData: Identifiable {
    let id: Date // Calendar.current.startOfDay
    let steps: Int?
    let sleepMinutes: Int?
    let activeEnergyKcal: Double?
}

// MARK: - HealthThresholds

enum HealthThresholds {
    enum Steps {
        static let low = 3000
        static let high = 8000
    }

    enum Sleep {
        static let short = 360 // 6 hours in minutes
        static let long = 480 // 8 hours in minutes
    }

    enum ActiveEnergy {
        static let low = 150.0 // kcal
        static let high = 400.0 // kcal
    }
}

// MARK: - NSCache Wrapper

private final class HealthDataCache {
    private let cache = NSCache<NSString, CacheEntry>()

    private final class CacheEntry {
        let data: DailyHealthData
        init(_ data: DailyHealthData) {
            self.data = data
        }
    }

    /// Use timeIntervalSince1970 as key (all dates are startOfDay, so this is unique and thread-safe)
    private func key(for date: Date) -> NSString {
        NSString(format: "%d", Int(date.timeIntervalSince1970))
    }

    func get(for date: Date) -> DailyHealthData? {
        cache.object(forKey: key(for: date))?.data
    }

    func set(_ data: DailyHealthData, for date: Date) {
        cache.setObject(CacheEntry(data), forKey: key(for: date))
    }

    func invalidateToday() {
        let today = Calendar.current.startOfDay(for: .now)
        cache.removeObject(forKey: key(for: today))
    }
}

// MARK: - HealthKitManager

@Observable
class HealthKitManager {
    private let store = HKHealthStore()
    private let cache = HealthDataCache()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis),
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Fetch Daily Data

    func fetchDailyData(for range: ClosedRange<Date>) async -> [DailyHealthData] {
        guard isAvailable else { return [] }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: range.lowerBound)
        let endDay = calendar.startOfDay(for: range.upperBound)
        let today = calendar.startOfDay(for: .now)

        // Collect dates in range
        var dates: [Date] = []
        var current = startDay
        while current <= endDay {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        // Check cache, collect dates needing fetch
        var cached: [Date: DailyHealthData] = [:]
        var toFetch: [Date] = []
        for date in dates {
            if let hit = cache.get(for: date) {
                cached[date] = hit
            } else {
                toFetch.append(date)
            }
        }

        guard !toFetch.isEmpty else {
            return dates.compactMap { cached[$0] }
        }

        // Fetch all metrics in parallel
        let fetchStart = toFetch.first!
        let fetchEnd = calendar.date(byAdding: .day, value: 1, to: toFetch.last!)!
        let fetchRange = fetchStart ... fetchEnd

        async let stepsResult = fetchSteps(range: fetchRange)
        async let energyResult = fetchActiveEnergy(range: fetchRange)
        async let sleepResult = fetchSleep(range: fetchRange)

        let stepsByDay = await stepsResult
        let energyByDay = await energyResult
        let sleepByDay = await sleepResult

        // Merge results
        var fetched: [Date: DailyHealthData] = [:]
        for date in toFetch {
            let data = DailyHealthData(
                id: date,
                steps: stepsByDay[date],
                sleepMinutes: sleepByDay[date],
                activeEnergyKcal: energyByDay[date]
            )
            fetched[date] = data

            // Cache past days with actual data (not today, since today's data changes)
            if date != today, data.steps != nil || data.sleepMinutes != nil || data.activeEnergyKcal != nil {
                cache.set(data, for: date)
            }
        }

        // Combine cached and fetched, exclude days with no data at all
        return dates.compactMap { cached[$0] ?? fetched[$0] }
            .filter { $0.steps != nil || $0.sleepMinutes != nil || $0.activeEnergyKcal != nil }
    }

    func invalidateTodayCache() {
        cache.invalidateToday()
    }

    // MARK: - HK Queries

    private func fetchSteps(range: ClosedRange<Date>) async -> [Date: Int] {
        await fetchCumulativeStatistics(
            type: HKQuantityType(.stepCount),
            unit: .count(),
            range: range,
            transform: { Int($0) }
        )
    }

    private func fetchActiveEnergy(range: ClosedRange<Date>) async -> [Date: Double] {
        await fetchCumulativeStatistics(
            type: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            range: range,
            transform: { $0 }
        )
    }

    private func fetchCumulativeStatistics<T>(
        type: HKQuantityType,
        unit: HKUnit,
        range: ClosedRange<Date>,
        transform: @escaping (Double) -> T
    ) async -> [Date: T] {
        await withCheckedContinuation { continuation in
            let interval = DateComponents(day: 1)
            let predicate = HKQuery.predicateForSamples(withStart: range.lowerBound, end: range.upperBound)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: range.lowerBound,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                var dict: [Date: T] = [:]
                if let results, error == nil {
                    results.enumerateStatistics(from: range.lowerBound, to: range.upperBound) { stats, _ in
                        if let sum = stats.sumQuantity() {
                            let value = sum.doubleValue(for: unit)
                            let day = Calendar.current.startOfDay(for: stats.startDate)
                            dict[day] = transform(value)
                        }
                    }
                }
                continuation.resume(returning: dict)
            }

            store.execute(query)
        }
    }

    private func fetchSleep(range: ClosedRange<Date>) async -> [Date: Int] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: range.lowerBound, end: range.upperBound)
            let sleepType = HKCategoryType(.sleepAnalysis)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                var dict: [Date: Int] = [:]
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: dict)
                    return
                }

                let calendar = Calendar.current
                // Only count actual sleep states (exclude inBed)
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                ]

                // Group sleep intervals by day, then merge overlapping intervals
                // to avoid double-counting from multiple sources (Watch + iPhone)
                var intervalsByDay: [Date: [(start: Date, end: Date)]] = [:]
                for sample in samples {
                    guard asleepValues.contains(sample.value) else { continue }
                    let day = calendar.startOfDay(for: sample.endDate)
                    intervalsByDay[day, default: []].append((sample.startDate, sample.endDate))
                }

                for (day, intervals) in intervalsByDay {
                    let sorted = intervals.sorted { $0.start < $1.start }
                    var merged: [(start: Date, end: Date)] = []
                    for interval in sorted {
                        if let last = merged.last, interval.start <= last.end {
                            // Overlapping — extend the end
                            merged[merged.count - 1] = (last.start, max(last.end, interval.end))
                        } else {
                            merged.append(interval)
                        }
                    }
                    let totalMinutes = merged.reduce(0) { sum, iv in
                        sum + Int(iv.end.timeIntervalSince(iv.start) / 60)
                    }
                    dict[day] = totalMinutes
                }

                continuation.resume(returning: dict)
            }

            store.execute(query)
        }
    }
}

// MARK: - Mock (Debug / Simulator)

#if DEBUG
    class MockHealthKitManager: HealthKitManager {
        override var isAvailable: Bool {
            true
        }

        override func requestAuthorization() async -> Bool {
            true
        }

        override func fetchDailyData(for range: ClosedRange<Date>) async -> [DailyHealthData] {
            let calendar = Calendar.current
            var result: [DailyHealthData] = []
            var current = calendar.startOfDay(for: range.lowerBound)
            let end = calendar.startOfDay(for: range.upperBound)

            while current <= end {
                result.append(DailyHealthData(
                    id: current,
                    steps: Int.random(in: 1000 ... 15000),
                    sleepMinutes: Int.random(in: 240 ... 600),
                    activeEnergyKcal: Double.random(in: 50 ... 600)
                ))
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
            return result
        }
    }
#endif

// MARK: - Environment Key

struct HealthKitManagerKey: EnvironmentKey {
    static let defaultValue = HealthKitManager()
}

extension EnvironmentValues {
    var healthKitManager: HealthKitManager {
        get { self[HealthKitManagerKey.self] }
        set { self[HealthKitManagerKey.self] = newValue }
    }
}
