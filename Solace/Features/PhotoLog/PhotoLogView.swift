//
//  PhotoLogView.swift
//  Solace
//

import PhotosUI
import SwiftUI
import UIKit

/// Photo capture → AI draft → editable review → save (Section 7's flagship
/// Tier-2 feature). The draft is never auto-saved — every field stays
/// editable until the user taps Save.
struct PhotoLogView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var userContext = ""
    @State private var isEstimating = false
    @State private var estimateError: String?
    @State private var draft: PhotoEstimateResult?
    @State private var mealSlot: MealSlot = .snack
    @State private var isSaving = false
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                if imageData != nil, draft == nil {
                    contextSection
                    estimateSection
                }
                if let draft {
                    draftSection(draft)
                }
            }
            .navigationTitle("Photo AI Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var imageSection: some View {
        Section("Photo") {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md, style: .continuous))
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(imageData == nil ? "Choose a Photo" : "Choose a Different Photo", systemImage: "photo")
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    imageData = try? await newItem?.loadTransferable(type: Data.self)
                    draft = nil
                    estimateError = nil
                    didSave = false
                    userContext = ""
                }
            }
        }
    }

    private var contextSection: some View {
        Section("Context (optional)") {
            TextField("e.g. \"added parmesan, large portion\"", text: $userContext)
        }
    }

    private var estimateSection: some View {
        Section {
            Button {
                Task { await estimate() }
            } label: {
                if isEstimating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Estimate with Photo AI", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.solaceAI)
            .disabled(isEstimating)

            if let estimateError {
                Text(estimateError).font(.solaceCaption).foregroundStyle(Color.solaceDestructive)
            }
        }
    }

    private func draftSection(_ draft: PhotoEstimateResult) -> some View {
        Group {
            Section {
                HStack {
                    Text("Confidence")
                    Spacer()
                    Text(draft.confidence, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(draft.confidence < 0.6 ? Color.solaceWarning : Color.solaceVitality)
                }
                Text("±15–30% typical error for single-item plates, more for composed dishes — always double-check before saving.")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Review & Edit")
            }

            Section("Identified Items") {
                ForEach(draft.items.indices, id: \.self) { index in
                    itemRow(index: index)
                }
            }

            Section {
                Picker("Meal", selection: $mealSlot) {
                    ForEach(MealSlot.allCases) { slot in Text(slot.displayName).tag(slot) }
                }
                let totalKcal = draft.items.reduce(0) { $0 + $1.kcal }
                if didSave {
                    Label("Logged to \(mealSlot.displayName)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.solaceVitality)
                } else {
                    Button {
                        Task { await save(draft) }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Save \(Int(totalKcal)) kcal to \(mealSlot.displayName)").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.solaceVitality)
                    .disabled(isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func itemRow(index: Int) -> some View {
        if let item = draft?.items[safe: index] {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name).font(.solaceBody)
                HStack {
                    Stepper(
                        "\(Int(item.estimatedGrams))g",
                        value: Binding(
                            get: { draft?.items[safe: index]?.estimatedGrams ?? item.estimatedGrams },
                            set: { newGrams in rescale(index: index, to: newGrams) }
                        ),
                        in: 1...2000,
                        step: 10
                    )
                    Spacer()
                    Text("\(Int(item.kcal)) kcal").font(.solaceLabel).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rescale(index: Int, to newGrams: Double) {
        guard var draft, draft.items.indices.contains(index) else { return }
        let rate = draft.items[index].perGram
        draft.items[index].estimatedGrams = newGrams
        draft.items[index].kcal = rate.kcal * newGrams
        draft.items[index].proteinG = rate.protein * newGrams
        draft.items[index].carbG = rate.carb * newGrams
        draft.items[index].fatG = rate.fat * newGrams
        self.draft = draft
    }

    private func estimate() async {
        guard let imageData else { return }
        isEstimating = true
        estimateError = nil
        defer { isEstimating = false }
        do {
            let settings = try await AIProviderSettingsRepository.current()
            let apiKey = KeychainStore.get(.aiProviderAPIKey) ?? ""
            draft = try await CloudPhotoEstimator.estimate(
                imageData: imageData, userContext: userContext, settings: settings, apiKey: apiKey
            )
        } catch {
            estimateError = error.localizedDescription
        }
    }

    private func save(_ draft: PhotoEstimateResult) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await DiaryRepository.logPhotoEstimate(draft, mealSlot: mealSlot)
            didSave = true
        } catch {
            estimateError = error.localizedDescription
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
