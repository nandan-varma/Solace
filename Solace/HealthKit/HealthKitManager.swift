//
//  HealthKitManager.swift
//  Solace
//

import Foundation
import HealthKit
import os

/// Opt-in, write-only sync of diary entries into Health (Section 8). Never
/// reads HealthKit data back into the app — App Review checks that
/// HealthKit-sourced data doesn't leave the device, and this app has no
/// reason to read it in the first place.
final class HealthKitManager: Sendable {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    private let didRequestAuthorization = OSAllocatedUnfairLock(initialState: false)

    private let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.dietaryProtein),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryFatTotal),
    ]

    /// Writes the entry's macros as four `HKQuantitySample`s and returns the
    /// entry's own id (used as `DiaryEntry.healthKitSampleUUID` for de-dup)
    /// on success, or `nil` if HealthKit sync isn't enabled/available.
    func write(_ entry: DiaryEntry) async throws -> UUID? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let profile = try await UserProfileRepository.current()
        guard profile.healthKitSyncEnabled else { return nil }

        let needsAuthorization = didRequestAuthorization.withLock { requested in
            defer { requested = true }
            return !requested
        }
        if needsAuthorization {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
        }

        // HKObject validates quantities at creation time and raises an
        // uncatchable NSException (not a Swift error) for non-finite or
        // negative values, which aborts the process. Guard before ever
        // constructing a sample.
        let values = [entry.energyKcal, entry.proteinsG, entry.carbohydratesG, entry.fatG]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }

        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            HKMetadataKeySyncIdentifier: entry.id.uuidString,
            HKMetadataKeySyncVersion: 1,
        ]

        let samples: [HKQuantitySample] = [
            HKQuantitySample(
                type: HKQuantityType(.dietaryEnergyConsumed),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: entry.energyKcal),
                start: entry.loggedAt, end: entry.loggedAt, metadata: metadata
            ),
            HKQuantitySample(
                type: HKQuantityType(.dietaryProtein),
                quantity: HKQuantity(unit: .gram(), doubleValue: entry.proteinsG),
                start: entry.loggedAt, end: entry.loggedAt, metadata: metadata
            ),
            HKQuantitySample(
                type: HKQuantityType(.dietaryCarbohydrates),
                quantity: HKQuantity(unit: .gram(), doubleValue: entry.carbohydratesG),
                start: entry.loggedAt, end: entry.loggedAt, metadata: metadata
            ),
            HKQuantitySample(
                type: HKQuantityType(.dietaryFatTotal),
                quantity: HKQuantity(unit: .gram(), doubleValue: entry.fatG),
                start: entry.loggedAt, end: entry.loggedAt, metadata: metadata
            ),
        ]

        try await store.save(samples)
        return entry.id
    }
}
