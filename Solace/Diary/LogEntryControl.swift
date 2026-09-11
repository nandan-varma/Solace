//
//  LogEntryControl.swift
//  Solace
//

import SwiftUI

/// Shared quantity + meal-slot + log button, used by every logging path
/// (barcode product, generic food search) so they converge on the same UX.
struct LogEntryControl: View {
    let onLog: (Double, MealSlot) async throws -> Void

    @State private var quantityGrams: Double = 100
    @State private var mealSlot: MealSlot = .snack
    @State private var isLogging = false
    @State private var logError: String?
    @State private var didLog = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if didLog {
                Label("Logged to \(mealSlot.displayName)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.solaceVitality)
                    .font(.solaceHeadlineSm)
            } else {
                Picker("Meal", selection: $mealSlot) {
                    ForEach(MealSlot.allCases) { slot in Text(slot.displayName).tag(slot) }
                }
                .pickerStyle(.segmented)

                Stepper("Quantity: \(Int(quantityGrams))g", value: $quantityGrams, in: 1...2000, step: 10)
                    .font(.solaceBodyMd)

                Button {
                    Task { await log() }
                } label: {
                    if isLogging {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Log \(Int(quantityGrams))g to \(mealSlot.displayName)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.solaceVitality)
                .disabled(isLogging)

                if let logError {
                    Text(logError).font(.solaceCaption).foregroundStyle(Color.solaceDestructive)
                }
            }
        }
        .padding(Spacing.lg)
        .solaceCard()
    }

    private func log() async {
        isLogging = true
        defer { isLogging = false }
        do {
            try await onLog(quantityGrams, mealSlot)
            didLog = true
        } catch {
            logError = error.localizedDescription
        }
    }
}
