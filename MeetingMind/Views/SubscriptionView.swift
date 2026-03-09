import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing24) {
                // Header band
                VStack(spacing: Theme.spacing8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)

                    Text("MeetingMind Pro")
                        .font(Theme.titleFont)
                        .foregroundStyle(.white)

                    Text("Unlock AI-powered meeting analysis")
                        .font(Theme.subheadlineFont)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacing40)
                .background(Theme.teal600)

                // Features
                VStack(spacing: Theme.spacing12) {
                    FeatureRow(icon: "text.bubble.fill", color: Theme.teal600,
                               title: "AI Meeting Summaries",
                               description: "Get concise summaries of your meetings")
                    FeatureRow(icon: "lightbulb.fill", color: Theme.insightBadge,
                               title: "Key Insights",
                               description: "Extract important decisions and topics")
                    FeatureRow(icon: "checklist", color: Theme.statusComplete,
                               title: "Action Items",
                               description: "Auto-extract tasks, reminders, and follow-ups")
                    FeatureRow(icon: "calendar.badge.plus", color: Theme.orange500,
                               title: "Calendar Integration",
                               description: "One-tap export to Calendar and Reminders")
                }
                .padding(.horizontal)

                // Pricing
                if let product = subscriptionService.product {
                    VStack(spacing: Theme.spacing8) {
                        Text(product.displayPrice)
                            .font(.system(size: 48, weight: .bold, design: .rounded))

                        Text("per month")
                            .font(Theme.subheadlineFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)

                    // Purchase button — orange CTA
                    Button {
                        Task {
                            let success = await subscriptionService.purchase()
                            if success { dismiss() }
                        }
                    } label: {
                        if subscriptionService.isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Subscribe Now")
                                .font(Theme.headlineFont)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Theme.orange500)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .disabled(subscriptionService.isPurchasing)
                    .padding(.horizontal)
                } else {
                    ProgressView("Loading...")
                }

                // Restore
                Button("Restore Purchases") {
                    Task { await subscriptionService.restorePurchases() }
                }
                .font(.footnote)

                // Error
                if let error = subscriptionService.errorMessage {
                    Text(error)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.coral)
                        .padding(.horizontal)
                }

                // Terms
                Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle("Subscribe")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await subscriptionService.loadProducts()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .font(.body)
                .frame(width: 36, height: 36)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.subheadlineFont)
                Text(description)
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Theme.cardPadding)
        .background(Theme.surfaceDefault)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}
