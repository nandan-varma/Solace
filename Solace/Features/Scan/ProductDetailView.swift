//
//  ProductDetailView.swift
//  Solace
//

import SwiftUI

/// Product evaluation screen — verified-safe banner, match-score ring,
/// regulatory badge row, key nutrients, laid out per `solace_scan_score_detail`.
struct ProductDetailView: View {
    let barcode: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .body) private var matchRingSize = 100
    @State private var product: CachedProduct?
    @State private var result: ScoreResult?
    @State private var profile: UserProfile?
    @State private var loadError: String?
    @State private var explanation: String?
    @State private var explanationError: String?
    @State private var isExplaining = false
    @State private var explainTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView {
                    Label("Couldn't Load Product", systemImage: "wifi.slash")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            } else if let product, let result {
                content(product: product, result: result)
            } else {
                ProgressView("Looking up \(barcode)…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.solaceCanvas)
        .navigationTitle("Product Evaluation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { explainTask?.cancel() }
    }

    private func content(product: CachedProduct, result: ScoreResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                sourceRow

                SafetyBanner(flags: result.safetyFlags)

                header(product: product)

                if let matchScore = result.matchScore {
                    matchScoreCard(matchScore: matchScore, breakdown: result.breakdown)
                }

                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Spacing.lg)) : AnyLayout(HStackLayout(spacing: Spacing.xl))) {
                    NutriScoreBadge(grade: result.nutriScoreGrade, version: product.nutriscoreVersion)
                    NovaBadge(group: result.novaGroup)
                    EcoScoreBadge(grade: result.ecoScoreGrade)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.lg)
                .solaceCard()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("KEY NUTRIENTS · PER 100G").font(.solaceCaption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: Spacing.sm) {
                        MacroPill(label: "Carbs", color: .solaceCarbs, valueGrams: product.carbohydrates100g)
                        MacroPill(label: "Protein", color: .solaceProtein, valueGrams: product.proteins100g)
                        MacroPill(label: "Fat", color: .solaceFat, valueGrams: product.fat100g)
                        MacroPill(label: "Sugars", color: .solaceWarning, valueGrams: product.sugars100g)
                    }
                }

                if profile?.onDeviceAIEnabled == true {
                    aiExplanationCard(product: product, result: result)
                }

                LogEntryControl { quantity, mealSlot in
                    try await DiaryRepository.logProduct(product, quantityGrams: quantity, mealSlot: mealSlot)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal")
                    Text("Data from Open Food Facts (ODbL)")
                }
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.lg)
        }
    }

    private var sourceRow: some View {
        HStack {
            Label(barcode, systemImage: "barcode")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Label("Open Food Facts", systemImage: "checkmark.seal.fill")
                .font(.solaceCaption)
                .foregroundStyle(Color.solaceVitality)
        }
    }

    private func header(product: CachedProduct) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            AsyncImage(url: product.imageURL.flatMap(URL.init)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.solaceFill.overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: Corner.sm, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let brands = product.brands {
                    Text(brands.uppercased()).font(.solaceLabel).foregroundStyle(.secondary)
                }
                Text(product.name ?? "Unknown product")
                    .font(.solaceHeadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func matchScoreCard(matchScore: Int, breakdown: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("MATCH SCORE").font(.solaceCaption).foregroundStyle(.secondary)
                Spacer()
                Text(fitLabel(for: matchScore))
                    .font(.solaceCaption)
                    .foregroundStyle(fitColor(for: matchScore))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(fitColor(for: matchScore).opacity(0.12), in: Capsule())
            }
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.lg)) : AnyLayout(HStackLayout(spacing: Spacing.lg))) {
                ScoreRing(
                    progress: Double(matchScore) / 100,
                    tint: fitColor(for: matchScore),
                    value: "\(matchScore)",
                    caption: "/ 100"
                )
                .frame(width: min(matchRingSize, 220), height: min(matchRingSize, 220))
                breakdownList(breakdown)
            }
        }
        .padding(Spacing.lg)
        .solaceCard()
    }

    private func fitLabel(for score: Int) -> String {
        switch score {
        case 80...: return "Great Fit"
        case 60..<80: return "Good Fit"
        case 40..<60: return "Fair Fit"
        default: return "Poor Fit"
        }
    }

    private func fitColor(for score: Int) -> Color {
        switch score {
        case 80...: return .solaceVitality
        case 60..<80: return .solaceInteractive
        case 40..<60: return .solaceWarning
        default: return .solaceDestructive
        }
    }

    private func breakdownColor(for factor: String) -> Color {
        switch factor {
        case "Nutri-Score": return .solaceVitality
        case "NOVA": return .solaceWarning
        case "Eco-Score": return .solaceInteractive
        default: return .solaceAI
        }
    }

    private func breakdownList(_ breakdown: [String: Double]) -> some View {
        // Contributions are weight × component, so displaying them raw reads
        // like the factor's own 0-100 score. Showing each as a share of the
        // total makes clear it's this factor's slice of the composite.
        let total = breakdown.values.reduce(0, +)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(breakdown.sorted(by: { $0.key < $1.key }), id: \.key) { factor, contribution in
                HStack(spacing: Spacing.xs) {
                    Circle().fill(breakdownColor(for: factor)).frame(width: 6, height: 6)
                    Text(factor).font(.solaceLabel)
                    Spacer()
                    Text(total > 0 ? contribution / total : 0, format: .percent.precision(.fractionLength(0)))
                        .font(.solaceLabel)
                        .foregroundStyle(.secondary)
                        .tabularNumbers()
                }
            }
        }
    }

    private func aiExplanationCard(product: CachedProduct, result: ScoreResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Apple Foundation Model", systemImage: "apple.logo")
                .font(.solaceHeadlineSm)
                .foregroundStyle(Color.solaceAI)

            if let explanation {
                Text(explanation).font(.solaceBodyMd)
            } else if let explanationError {
                Text(explanationError).font(.solaceCaption).foregroundStyle(.secondary)
                Button("Try Again") {
                    self.explanationError = nil
                    explainTask = Task { await explain(product: product, result: result) }
                }
                .font(.solaceLabel)
            } else {
                Button {
                    explainTask = Task { await explain(product: product, result: result) }
                } label: {
                    if isExplaining {
                        ProgressView().tint(.white)
                    } else {
                        Label("Explain This Score", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.solacePrimary(.solaceAI))
                .disabled(isExplaining)
            }

            Label("Private & offline — synthesized on-device.", systemImage: "lock.fill")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .fill(Color.solaceAI.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .strokeBorder(Color.solaceAI.opacity(0.15), lineWidth: 1)
        )
    }

    private func explain(product: CachedProduct, result: ScoreResult) async {
        isExplaining = true
        defer { isExplaining = false }
        do {
            let text = try await OnDeviceExplainer.explain(food: product.scoringInput, result: result)
            guard !Task.isCancelled else { return }
            explanation = text
        } catch let error as OnDeviceExplainerError {
            guard !Task.isCancelled else { return }
            if case .unavailable(let reason) = error {
                explanationError = reason.userFacingMessage
            }
        } catch {
            guard !Task.isCancelled else { return }
            explanationError = error.localizedDescription
        }
    }

    private func load() async {
        loadError = nil
        do {
            let product = try await ProductRepository.product(forBarcode: barcode)
            let profile = try await UserProfileRepository.current()
            self.product = product
            self.profile = profile
            self.result = ScoringEngine.evaluate(product.scoringInput, profile: profile)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(barcode: "3017620422003")
    }
}
