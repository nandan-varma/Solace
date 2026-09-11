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
    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var userContext = ""
    @State private var isEstimating = false
    @State private var estimateError: String?
    @State private var draft: PhotoEstimateResult?
    @State private var mealSlot: MealSlot = .current()
    @State private var isSaving = false
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    photoPicker
                    if imageData != nil, draft == nil {
                        contextField
                        estimateButton
                    }
                    if let draft {
                        draftReview(draft)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.solaceCanvas)
            .navigationTitle("Photo AI Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog("Add a Photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
                if CameraCaptureView.isAvailable {
                    Button("Take Photo") { showCamera = true }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Choose from Library")
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(
                    onCapture: { data in
                        applyNewImage(data)
                        showCamera = false
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        applyNewImage(data)
                    }
                }
            }
        }
    }

    // MARK: - Photo

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("PHOTO").font(.solaceCaption).foregroundStyle(.secondary)
            Button { showSourcePicker = true } label: {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Corner.lg, style: .continuous))
                        Label("Retake", systemImage: "arrow.triangle.2.circlepath")
                            .font(.solaceCaption)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(Spacing.sm)
                    }
                } else {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.solaceAI)
                        Text("Add a Photo")
                            .font(.solaceHeadlineSm)
                        Text("Take a picture or choose one from your library")
                            .font(.solaceCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                            .strokeBorder(Color.solaceAI.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    )
                    .background(Color.solaceAI.opacity(0.05), in: RoundedRectangle(cornerRadius: Corner.lg, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func applyNewImage(_ data: Data) {
        imageData = data
        draft = nil
        estimateError = nil
        didSave = false
        userContext = ""
    }

    private var contextField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CONTEXT (OPTIONAL)").font(.solaceCaption).foregroundStyle(.secondary)
            TextField("e.g. \"added parmesan, large portion\"", text: $userContext)
                .padding(Spacing.md)
                .background(Color.solaceFill, in: RoundedRectangle(cornerRadius: Corner.sm, style: .continuous))
        }
    }

    private var estimateButton: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                Task { await estimate() }
            } label: {
                if isEstimating {
                    ProgressView().tint(.white)
                } else {
                    Label("Estimate with Photo AI", systemImage: "sparkles")
                }
            }
            .buttonStyle(.solacePrimary(.solaceAI))
            .disabled(isEstimating)

            if let estimateError {
                Label(estimateError, systemImage: "exclamationmark.triangle.fill")
                    .font(.solaceCaption)
                    .foregroundStyle(Color.solaceDestructive)
            }
        }
    }

    // MARK: - Draft review

    private func draftReview(_ draft: PhotoEstimateResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            confidenceCard(draft)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("IDENTIFIED ITEMS \u{00b7} TAP +/- TO ADJUST").font(.solaceCaption).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(draft.items.indices), id: \.self) { index in
                        itemRow(index: index)
                        if index < draft.items.count - 1 {
                            Divider().padding(.leading, Spacing.md)
                        }
                    }
                }
                .solaceCard()
            }

            saveCard(draft)
        }
    }

    private func confidenceCard(_ draft: PhotoEstimateResult) -> some View {
        let (label, color): (String, Color) = draft.confidence >= 0.75
            ? ("High Confidence", .solaceVitality)
            : draft.confidence >= 0.5 ? ("Moderate Confidence", .solaceWarning) : ("Low Confidence", .solaceDestructive)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label(label, systemImage: "gauge.with.dots.needle.50percent")
                    .font(.solaceHeadlineSm)
                    .foregroundStyle(color)
                Spacer()
                Text(draft.confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.solaceLabel)
                    .foregroundStyle(color)
            }
            ProgressView(value: draft.confidence).tint(color)
            Text("Typical error is \u{00b1}15\u{2013}30% for single-item plates, more for composed dishes \u{2014} always double-check before saving.")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .solaceCard()
    }

    private func itemRow(index: Int) -> some View {
        Group {
            if let item = draft?.items[safe: index] {
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.solaceBody)
                        Text("\(Int(item.kcal)) kcal").font(.solaceCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper(
                        value: Binding(
                            get: { draft?.items[safe: index]?.estimatedGrams ?? item.estimatedGrams },
                            set: { newGrams in rescale(index: index, to: newGrams) }
                        ),
                        in: 1...2000,
                        step: 10
                    ) {
                        Text("\(Int(item.estimatedGrams))g")
                            .font(.solaceLabel)
                            .tabularNumbers()
                            .frame(width: 52, alignment: .trailing)
                    }
                    .fixedSize()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    private func saveCard(_ draft: PhotoEstimateResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if didSave {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.solaceVitality)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Logged").font(.solaceHeadlineSm)
                        Text("to \(mealSlot.displayName)").font(.solaceCaption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("MEAL").font(.solaceCaption).foregroundStyle(.secondary)
                HStack(spacing: Spacing.sm) {
                    ForEach(MealSlot.allCases) { slot in
                        Button {
                            mealSlot = slot
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: slot.icon).font(.system(size: 15))
                                Text(slot.displayName).font(.solaceCaption)
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

                let totalKcal = draft.items.reduce(0) { $0 + $1.kcal }
                Button {
                    Task { await save(draft) }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save \(Int(totalKcal)) kcal to \(mealSlot.displayName)")
                    }
                }
                .buttonStyle(.solacePrimary())
                .disabled(isSaving)
            }
        }
        .padding(Spacing.lg)
        .solaceCard()
        .animation(.easeOut(duration: 0.25), value: didSave)
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
