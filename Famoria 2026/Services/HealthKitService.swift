//
//  HealthKitService.swift
//  Famoria 2026
//
//  Thin wrapper around `HKHealthStore` that surfaces a "today" snapshot
//  of the signed-in user's steps, sleep duration, and resting heart
//  rate. Read-only, no writes back to the Health app — Famoria is not
//  a healthcare provider.
//
//  Requires (in Xcode):
//    1. "HealthKit" capability on the Famoria 2026 target.
//    2. INFOPLIST_KEY_NSHealthShareUsageDescription string (e.g.
//       "Famoria shows your daily steps, sleep, and heart rate in the
//       Health Center so you can keep tabs on your wellbeing.")
//
//  Until both are set the calls below throw at runtime; we surface the
//  error as `isAvailable = false` so the UI can hide the card.
//

import Foundation
import os
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class HealthKitService: ObservableObject {

    @Published private(set) var isAvailable = false
    @Published private(set) var stepsToday: Int = 0
    @Published private(set) var sleepHoursLastNight: Double = 0
    @Published private(set) var restingHeartRate: Double = 0

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    private var readTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { set.insert(steps) }
        if let hr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { set.insert(hr) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        return set
    }
    #endif

    /// Requests read authorization for the three types we care about.
    /// HealthKit doesn't tell us whether the user said yes (privacy), so
    /// we treat success of `requestAuthorization` as "available" and
    /// rely on empty results when the user denied.
    func requestAuthorization() async {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            isAvailable = false
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAvailable = true
            await refresh()
        } catch {
            Log.health.error("HealthKit auth failed: \(error.localizedDescription, privacy: .public)")
            isAvailable = false
        }
        #else
        isAvailable = false
        #endif
    }

    /// Refreshes the published snapshot. Safe to call from `onAppear`
    /// after `requestAuthorization`.
    func refresh() async {
        #if canImport(HealthKit)
        async let steps = readStepsToday()
        async let sleep = readSleepLastNight()
        async let hr = readRestingHeartRate()
        let (s, sl, h) = await (steps, sleep, hr)
        self.stepsToday = s
        self.sleepHoursLastNight = sl
        self.restingHeartRate = h
        #endif
    }

    #if canImport(HealthKit)

    // MARK: - Queries

    private func readStepsToday() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { (cont: CheckedContinuation<Int, Never>) in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                let count = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(count))
            }
            store.execute(q)
        }
    }

    private func readSleepLastNight() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let cal = Calendar.current
        // "Last night" = yesterday 8pm → today 11am.
        let now = Date()
        guard let endRef = cal.date(bySettingHour: 11, minute: 0, second: 0, of: now),
              let startRef = cal.date(byAdding: .hour, value: -15, to: endRef) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startRef, end: endRef, options: .strictStartDate)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let total = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total / 3600.0)
            }
            store.execute(q)
        }
    }

    private func readRestingHeartRate() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return 0 }
        // Average of the last 7 days' RHR readings.
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                cont.resume(returning: value)
            }
            store.execute(q)
        }
    }
    #endif
}
