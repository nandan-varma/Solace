//
//  LogEntryControl.swift
//  Solace
//

import SwiftUI

/// Shared quantity + meal-slot + log button, used by every logging path
/// (barcode product, generic food search) so they converge on the same UX.
struct LogEntryControl: View {
    var onDone: (() -> Void)? = nil
    let onLog: (Double, MealSlot) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var quantityFocused: Bool
    @State private var quantityText = "100"
    private var quantityGrams: Double {
        (try? Double(quantityText, format: .number)) ?? .nan
    }
    private var validQuantity: Bool { quantityGrams.isFinite && (1...2000).contains(quantityGrams) }
    private var formattedQuantity: String {
        validQuantity ? quantityGrams.formatted(.number.precision(.fractionLength(0...1))) : "—"
    }
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
                        Text("\(formattedQuantity) g to \(mealSlot.displayName)")
                            .font(.solaceCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
                Button("Done") {
                    if let onDone { onDone() } else { dismiss() }
                }.buttonStyle(.solacePrimary())
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("MEAL").font(.solaceCaption).foregroundStyle(.secondary)
                    MealSlotPicker(selection: $mealSlot).disabled(isLogging)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("QUANTITY").font(.solaceCaption).foregroundStyle(.secondary)
                    quantityStepper.disabled(isLogging)
                    if !validQuantity {
                        Text("Enter a portion from 1 to 2,000 grams.")
                            .font(.footnote).foregroundStyle(Color.solaceDestructive)
                    }
                }

                Button {
                    Task { await log() }
                } label: {
                    if isLogging {
                        ProgressView().tint(.white)
                    } else {
                        Text("Log \(formattedQuantity) g to \(mealSlot.displayName)")
                    }
                }
                .buttonStyle(.solacePrimary())
                .disabled(isLogging || !validQuantity)

                if let logError {
                    Label(logError, systemImage: "exclamationmark.triangle.fill")
                        .font(.solaceCaption)
                        .foregroundStyle(Color.solaceDestructive)
                }
            }
        }
        .padding(Spacing.lg)
        .solaceCard()
        .sensoryFeedback(.success, trigger: didLog)
        .animation(.easeOut(duration: 0.25), value: didLog)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { quantityFocused = false }
            }
        }
    }

    private var quantityStepper: some View {
        HStack {
            stepButton(systemImage: "minus", action: { adjust(by: -10) })
                .disabled(validQuantity && quantityGrams <= 1)
            Spacer()
            TextField("Grams", text: $quantityText)
                .accessibilityIdentifier("log.quantity")
                .keyboardType(.decimalPad)
                .focused($quantityFocused)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Quantity in grams")
                .font(.solaceStat(size: 22))
                .tabularNumbers()
                .contentTransition(.numericText())
                .animation(.default, value: quantityText)
            Text("g")
                .font(.solaceBodyMd)
                .foregroundStyle(.secondary)
            Spacer()
            stepButton(systemImage: "plus", action: { adjust(by: 10) })
                .disabled(validQuantity && quantityGrams >= 2000)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(Color.solaceFill, in: RoundedRectangle(cornerRadius: Corner.sm, style: .continuous))
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Color.solaceCard, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemImage == "minus" ? "Decrease quantity by 10 grams" : "Increase quantity by 10 grams")
    }

    private func adjust(by delta: Double) {
        let value = min(2000, max(1, (validQuantity ? quantityGrams : 100) + delta))
        quantityText = value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }

    private func log() async {
        guard quantityGrams.isFinite, (1...2000).contains(quantityGrams), !isLogging else { return }
        quantityFocused = false
        logError = nil
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
