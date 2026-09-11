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
    @State private var mealSlot: MealSlot = .current()
    @State private var isLogging = false
    @State private var logError: String?
    @State private var didLog = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if didLog {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.solaceVitality)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Logged").font(.solaceHeadlineSm)
                        Text("\(Int(quantityGrams))g to \(mealSlot.displayName)")
                            .font(.solaceCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("MEAL").font(.solaceCaption).foregroundStyle(.secondary)
                    mealSlotPicker
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("QUANTITY").font(.solaceCaption).foregroundStyle(.secondary)
                    quantityStepper
                }

                Button {
                    Task { await log() }
                } label: {
                    if isLogging {
                        ProgressView().tint(.white)
                    } else {
                        Text("Log \(Int(quantityGrams))g to \(mealSlot.displayName)")
                    }
                }
                .buttonStyle(.solacePrimary())
                .disabled(isLogging)

                if let logError {
                    Label(logError, systemImage: "exclamationmark.triangle.fill")
                        .font(.solaceCaption)
                        .foregroundStyle(Color.solaceDestructive)
                }
            }
        }
        .padding(Spacing.lg)
        .solaceCard()
        .animation(.easeOut(duration: 0.25), value: didLog)
    }

    private var mealSlotPicker: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(MealSlot.allCases) { slot in
                Button {
                    mealSlot = slot
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: slot.icon)
                            .font(.system(size: 15))
                        Text(slot.displayName)
                            .font(.solaceCaption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .foregroundStyle(mealSlot == slot ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: Corner.sm, style: .continuous)
                            .fill(mealSlot == slot ? slot.tint : Color.solaceFill)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quantityStepper: some View {
        HStack {
            stepButton(systemImage: "minus", action: { adjust(by: -10) })
            Spacer()
            Text("\(Int(quantityGrams))")
                .font(.solaceStat(size: 22))
                .tabularNumbers()
                .contentTransition(.numericText())
                .animation(.default, value: quantityGrams)
            Text("g")
                .font(.solaceBodyMd)
                .foregroundStyle(.secondary)
            Spacer()
            stepButton(systemImage: "plus", action: { adjust(by: 10) })
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(Color.solaceFill, in: RoundedRectangle(cornerRadius: Corner.sm, style: .continuous))
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
                .background(Color.solaceCard, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func adjust(by delta: Double) {
        quantityGrams = min(2000, max(1, quantityGrams + delta))
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
