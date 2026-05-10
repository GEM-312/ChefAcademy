//
//  PaywallView.swift
//  ChefAcademy
//
//  "Upgrade to Pip Chat" subscription sheet. Presented when a base-tier user
//  tries to use a premium feature (free-form chat, Surprise me, recipe gen).
//
//  Zero hardcoded values — all dimensions/colors/fonts come from design tokens.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var purchasing = false

    private var product: Product? {
        subscriptionManager.products[PipProductID.pipChatMonthly]
    }

    private var priceText: String {
        product?.displayPrice ?? "$3.99"
    }

    private var trialText: String {
        // StoreKit 2 exposes introductory offer metadata — prefer it if available.
        if let offer = product?.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial,
           let period = offer.period.formatted() {
            return "Free for \(period), then \(priceText)/month"
        }
        return "7 days free, then \(priceText)/month"
    }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    closeButton
                    heroSection
                    benefitsList
                    pricingSection
                    ctaButtons
                    disclosureSection
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            // Re-fetch if products missed the initial app-launch load (ASC propagation timing)
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.sepia.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppSpacing.sm) {
            PipWavingAnimatedView(size: AdaptiveCardSize.pipReadyScreen(for: sizeClass))

            Text("Unlock Pip Chat")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("Chat with Pip about anything, anytime.")
                .font(.AppTheme.title3)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            benefitRow(icon: "bubble.left.and.bubble.right.fill",
                       title: "Chat with Pip about anything",
                       subtitle: "Free-form questions, real conversations")

            benefitRow(icon: "fork.knife",
                       title: "Personalized recipe ideas",
                       subtitle: "Based on what you grew and bought")

            benefitRow(icon: "leaf.fill",
                       title: "Growing tips for your plants",
                       subtitle: "Tailored to your garden and weather")

            benefitRow(icon: "heart.fill",
                       title: "Nutrition advice for YOUR body",
                       subtitle: "Foods that help weak organs")

            benefitRow(icon: "person.3.fill",
                       title: "Family Sharing supported",
                       subtitle: "One subscription, every kid on this device")
        }
        .softCard()
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.AppTheme.title3)
                .foregroundColor(Color.AppTheme.sage)
                .frame(width: AppSpacing.iconSize)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.AppTheme.bodyBold)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(subtitle)
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(trialText)
                .font(.AppTheme.title3)
                .foregroundColor(Color.AppTheme.darkBrown)
                .multilineTextAlignment(.center)

            Text("Cancel anytime")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
    }

    // MARK: - CTAs

    private var ctaButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            if let product {
                Button {
                    Task { await handlePurchase(product) }
                } label: {
                    if purchasing {
                        HStack(spacing: AppSpacing.xs) {
                            ProgressView()
                                .tint(Color.AppTheme.cream)
                            Text("Subscribing…")
                        }
                    } else {
                        Text("Start Free Trial")
                    }
                }
                .texturedButton(tint: Color.AppTheme.sage)
                .disabled(purchasing)
            } else {
                Text("Subscription unavailable right now")
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(AppSpacing.sm)
            }

            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .secondaryButton()

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.terracotta)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xs)
            }

            Button("Maybe later") {
                dismiss()
            }
            .font(.AppTheme.subheadline)
            .foregroundColor(Color.AppTheme.sepia)
            .padding(.top, AppSpacing.xs)
        }
    }

    // MARK: - Apple-required disclosure

    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Free for 7 days, then \(priceText)/month. Auto-renews unless cancelled at least 24 hours before the end of the trial. Cancel anytime in Settings.")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia.opacity(0.8))

            HStack(spacing: AppSpacing.md) {
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://chefacademy.app/privacy")!)
            }
            .font(.AppTheme.caption)
            .foregroundColor(Color.AppTheme.sage)
        }
        .padding(.top, AppSpacing.md)
    }

    // MARK: - Actions

    private func handlePurchase(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }

        let success = await subscriptionManager.purchase(product)
        if success {
            dismiss()
        }
    }
}

// MARK: - SubscriptionPeriod formatter

private extension Product.SubscriptionPeriod {
    func formatted() -> String? {
        let unitName: String
        switch unit {
        case .day:   unitName = value == 1 ? "day" : "days"
        case .week:  unitName = value == 1 ? "week" : "weeks"
        case .month: unitName = value == 1 ? "month" : "months"
        case .year:  unitName = value == 1 ? "year" : "years"
        @unknown default: return nil
        }
        return "\(value) \(unitName)"
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
