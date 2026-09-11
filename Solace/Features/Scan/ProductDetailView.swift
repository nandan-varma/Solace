//
//  ProductDetailView.swift
//  Solace
//

import SwiftUI

/// Product evaluation screen — verified-safe banner, match-score ring,
/// regulatory badge row, key nutrients, laid out per `solace_scan_score_detail`.
struct ProductDetailView: View {
    let barcode: String

    @State private var product: CachedProduct?
    @State private var result: ScoreResult?
    @State private var profile: UserProfile?
    @State private var loadError: String?
    @State private var explanation: String?
    @State private var explanationError: String?
    @State private var isExplaining = false

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Couldn't Load Product", systemImage: "wifi.slash", description: Text(loadError))
            } else if let product, let result {
                content(product: product, result: result)
            } else {
                ProgressView("Looking up \(barcode)…")
            }
        }
        .navigationTitle("Product Evaluation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func content(product: CachedProduct, result: ScoreResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SafetyBanner(flags: result.safetyFlags)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let brands = product.brands { Text(brands.uppercased()).font(.solaceLabel).foregroundStyle(.secondary) }
                    Text(product.name ?? "Unknown product").font(.solaceHeadline)
                }

                if let matchScore = result.matchScore {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("MATCH SCORE").font(.solaceCaption).foregroundStyle(.secondary)
                        HStack(spacing: Spacing.lg) {
                            ScoreRing(
                                progress: Double(matchScore) / 100,
                                tint: .solaceVitality,
                                value: "\(matchScore)",
                                caption: "/ 100"
                            )
                            .frame(width: 100, height: 100)
                            breakdownList(result.breakdown)
                        }
                    }
                    .padding(Spacing.lg)
                    .solaceCard()
                }

                HStack(spacing: Spacing.xl) {
                    NutriScoreBadge(grade: result.nutriScoreGrade)
                    NovaBadge(group: result.novaGroup)
                    GreenScoreBadge(grade: result.greenScoreGrade)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.lg)
                .solaceCard()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("KEY NUTRIENTS (per 100g)").font(.solaceCaption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                        MacroPill(label: "Carbs", color: .solaceCarbs, valueGrams: product.carbohydrates100g ?? 0)
                        MacroPill(label: "Protein", color: .solaceProtein, valueGrams: product.proteins100g ?? 0)
                        MacroPill(label: "Fat", color: .solaceFat, valueGrams: product.fat100g ?? 0)
                        MacroPill(label: "Sugars", color: .solaceWarning, valueGrams: product.sugars100g ?? 0)
                    }
                }

                if profile?.onDeviceAIEnabled == true {
                    aiExplanationCard(product: product, result: result)
                }

                LogEntryControl { quantity, mealSlot in
                    try await DiaryRepository.logProduct(product, quantityGrams: quantity, mealSlot: mealSlot)
                }

                Text("Data from Open Food Facts (ODbL)")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.lg)
        }
    }

    private func breakdownList(_ breakdown: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(breakdown.sorted(by: { $0.key < $1.key }), id: \.key) { factor, contribution in
                HStack {
                    Text(factor).font(.solaceLabel)
                    Spacer()
                    Text(contribution, format: .number.precision(.fractionLength(1)))
                        .font(.solaceLabel)
                        .foregroundStyle(.secondary)
                        .tabularNumbers()
                }
            }
        }
    }

    private func aiExplanationCard(product: CachedProduct, result: ScoreResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Apple Foundation Model", systemImage: "sparkles")
                .font(.solaceHeadlineSm)
                .foregroundStyle(Color.solaceAI)

            if let explanation {
                Text(explanation).font(.solaceBodyMd)
            } else if let explanationError {
                Text(explanationError).font(.solaceCaption).foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await explain(product: product, result: result) }
                } label: {
                    if isExplaining {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Explain This Score", systemImage: "sparkles").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.solaceAI)
                .disabled(isExplaining)
            }

            Text("Private & offline — synthesized on-device.")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .solaceCard()
    }

    private func explain(product: CachedProduct, result: ScoreResult) async {
        isExplaining = true
        defer { isExplaining = false }
        do {
            explanation = try await OnDeviceExplainer.explain(food: product.scoringInput, result: result)
        } catch let error as OnDeviceExplainerError {
            if case .unavailable(let reason) = error {
                explanationError = reason.userFacingMessage
            }
        } catch {
            explanationError = error.localizedDescription
        }
    }

    private func load() async {
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
