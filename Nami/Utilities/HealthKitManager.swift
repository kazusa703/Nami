//
//  HealthKitManager.swift
//  Nami
//
//  HealthKit data access for mood-health correlation analysis
//

import Foundation
import HealthKit
import SwiftUI

/// Daily health metrics for correlation with mood data
struct DailyHealthMetric: Sendable {
    let date: Date
    let steps: Double?
    let sleepHours: Double?
    let restingHeartRate: Double?
    let headphoneMinutes: Double?
}

/// Manages HealthKit authorization and data queries
@Observable
@MainActor
final class HealthKitManager {
    // MARK: - State

    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Current authorization status (nil = not determined)
    var isAuthorized: Bool = false

    /// User preference to enable HealthKit integration
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "healthKitEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "healthKitEnabled")
            if newValue && !isAuthorized {
                Task { await requestAuthorization() }
            }
        }
    }

    /// Cached daily metrics for current display
    var cachedMetrics: [Date: DailyHealthMetric] = [:]

    // MARK: - Private

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let hr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(hr)
        }
        if let headphone = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) {
            types.insert(headphone)
        }
        return types
    }()

    // MARK: - Authorization

    /// Request HealthKit read authorization
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            UserDefaults.standard.set(true, forKey: "healthKitAuthorized")
            return true
        } catch {
            print("HealthKit authorization error: \(error)")
            isAuthorized = false
            return false
        }
    }

    /// Check current authorization status by attempting a small query
    func checkAuthorizationStatus() async {
        guard isAvailable, isEnabled else {
            isAuthorized = false
            return
        }
        // HealthKit read authorization can only be verified by querying data
        // A successful query indicates authorization was granted
        let steps = await fetchSteps(for: .now)
        // If the query returns nil it could mean no data OR denied;
        // we mark as authorized if the user previously enabled it
        isAuthorized = steps != nil || UserDefaults.standard.bool(forKey: "healthKitAuthorized")
    }

    // MARK: - Data Queries

    /// Fetch step count for a specific date
    func fetchSteps(for date: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Fetch sleep hours for a specific date (the night ending on that date)
    func fetchSleepHours(for date: Date) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        // Look back to previous evening
        guard let queryStart = calendar.date(byAdding: .hour, value: -12, to: start) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                // Sum asleep intervals (exclude inBed-only)
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            store.execute(query)
        }
    }

    /// Fetch resting heart rate for a specific date
    func fetchRestingHeartRate(for date: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                let value = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Fetch total headphone listening minutes for a specific date
    func fetchHeadphoneMinutes(for date: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) else { return nil }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                guard let samples = results as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // Sum duration of all headphone audio samples
                let totalSeconds = samples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                continuation.resume(returning: totalSeconds / 60.0) // minutes
            }
            store.execute(query)
        }
    }

    /// Fetch daily metrics for a date range
    func fetchDailyMetrics(from startDate: Date, to endDate: Date) async -> [DailyHealthMetric] {
        let calendar = Calendar.current
        var metrics: [DailyHealthMetric] = []
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while current <= end {
            let day = current
            async let steps = fetchSteps(for: day)
            async let sleep = fetchSleepHours(for: day)
            async let hr = fetchRestingHeartRate(for: day)
            async let headphone = fetchHeadphoneMinutes(for: day)

            let metric = DailyHealthMetric(
                date: day,
                steps: await steps,
                sleepHours: await sleep,
                restingHeartRate: await hr,
                headphoneMinutes: await headphone
            )
            metrics.append(metric)
            cachedMetrics[day] = metric

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }

        return metrics
    }

    // MARK: - Correlation Analysis

    /// Calculate Pearson correlation between mood scores and a health metric
    static func correlation(
        moodScores: [(date: Date, normalizedScore: Double)],
        healthValues: [(date: Date, value: Double)]
    ) -> Double? {
        let calendar = Calendar.current

        // Match by date
        var paired: [(mood: Double, health: Double)] = []
        let healthByDate = Dictionary(grouping: healthValues) { calendar.startOfDay(for: $0.date) }
            .compactMapValues { $0.first?.value }

        for mood in moodScores {
            let day = calendar.startOfDay(for: mood.date)
            if let health = healthByDate[day] {
                paired.append((mood.normalizedScore, health))
            }
        }

        guard paired.count >= 7 else { return nil }

        let n = Double(paired.count)
        let sumX = paired.reduce(0.0) { $0 + $1.mood }
        let sumY = paired.reduce(0.0) { $0 + $1.health }
        let sumXY = paired.reduce(0.0) { $0 + $1.mood * $1.health }
        let sumX2 = paired.reduce(0.0) { $0 + $1.mood * $1.mood }
        let sumY2 = paired.reduce(0.0) { $0 + $1.health * $1.health }

        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        guard denominator > 0 else { return nil }

        return (n * sumXY - sumX * sumY) / denominator
    }
}

// MARK: - Environment Key

private struct HealthKitManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = HealthKitManager()
}

extension EnvironmentValues {
    var healthKitManager: HealthKitManager {
        get { self[HealthKitManagerKey.self] }
        set { self[HealthKitManagerKey.self] = newValue }
    }
}
