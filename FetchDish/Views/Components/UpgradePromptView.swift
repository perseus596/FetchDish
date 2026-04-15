import SwiftUI
import StoreKit

/// Full-screen upgrade sheet shown when user hits a free-tier limit.
struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var proManager = ProManager.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String? = nil

    /// Optional custom message shown at the top (e.g. "You've reached the 5-recipe limit")
    var triggerMessage: String? = nil

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.2)

    private let features: [(icon: String, title: String, description: String)] = [
        ("book.fill",           "Unlimited Recipes",        "Save as many recipes as you want."),
        ("timer",               "Per-Step Timers",          "Tap any step to start a countdown timer."),
        ("speedometer",         "Adjustable Cook Speed",    "Control auto-scroll speed in cooking mode."),
        ("tablecells.fill",     "Full Conversion Table",    "All unit conversions at your fingertips."),
        ("fork.knife.circle",   "Unlimited Ingredients",    "Use all ingredients in What Can I Cook?"),
        ("heart.text.clipboard","Dietary & Allergy Profile","Set your preferences once, filter forever."),
        ("star.fill",           "Favorite Ingredients",     "Save your go-to ingredients for quick access."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.92, blue: 0.4),
                                    Color(red: 0.95, green: 0.75, blue: 0.1),
                                    Color(red: 0.8,  green: 0.55, blue: 0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: gold.opacity(0.5), radius: 10, y: 3)
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(red: 1.0, green: 0.95, blue: 0.6).opacity(0.4))
                }

                Text("FetchDish Pro")
                    .font(.system(size: 28, weight: .bold, design: .serif))

                if let msg = triggerMessage {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text("One-time purchase. No subscription. No ads. Ever.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            Divider()

            // Feature list
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(features, id: \.title) { feature in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(gold)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(feature.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }

            Divider()

            // Purchase area
            VStack(spacing: 12) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        isPurchasing = true
                        errorMessage = nil
                        await proManager.purchase()
                        isPurchasing = false
                        if case .failed(let msg) = proManager.purchaseState {
                            errorMessage = msg
                        } else if proManager.isPro {
                            dismiss()
                        }
                    }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView()
                                .controlSize(.regular)
                        } else {
                            let priceString = proManager.product.map { $0.displayPrice } ?? "$19.99"
                            Text("Unlock Pro — \(priceString)")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.92, blue: 0.4),
                                Color(red: 0.95, green: 0.75, blue: 0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isPurchasing)

                Button {
                    Task {
                        await proManager.restorePurchases()
                        if proManager.isPro { dismiss() }
                    }
                } label: {
                    Text("Restore Purchase")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button("Maybe Later") { dismiss() }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(width: 420, height: 620)
    }
}
