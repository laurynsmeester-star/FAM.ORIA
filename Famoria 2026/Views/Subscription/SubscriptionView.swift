//
//  SubscriptionView.swift
//  Famoria 2026
//
//  Apple-quality paywall for Famoria Plus. Loads StoreKit products,
//  highlights the annual plan with a "Save 28%" chip + free-trial
//  callout, and exposes a Restore Purchases button. Used both as the
//  upgrade entry-point from Profile and as a sheet presented by the
//  `.requiresPremium()` view modifier when the user taps a gated
//  feature.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: FamoriaProduct = .annual

    private var manager: SubscriptionManager { appState.subscriptionManager }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    benefitsSection
                    pricingSection
                    if manager.currentStatus == .free {
                        trialCallout
                    }
                    actions
                    legalDisclosure
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.10), Color.pink.opacity(0.06), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Famoria Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await manager.loadProducts()
                await manager.refreshEntitlement()
            }
            .alert("Couldn't complete that",
                   isPresented: .constant(manager.lastError != nil),
                   presenting: manager.lastError) { _ in
                Button("OK", role: .cancel) { manager.lastError = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .pink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Famoria Plus")
                        .font(.title2.bold())
                    Text("Built for the whole family.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow("infinity", "Unlimited Family Members",
                       "Invite parents, grandparents, in-laws, cousins.")
            benefitRow("externaldrive.fill.badge.icloud", "100 GB Secure Storage",
                       "Photos, videos, journals, recipes — all together.")
            benefitRow("folder.fill.badge.person.crop", "Private Family Vault",
                       "Legal, medical, insurance docs with granular privacy.")
            benefitRow("heart.text.square", "Health Tracking Center",
                       "Appointments, goals, family health summaries.")
            benefitRow("lock.shield.fill", "Advanced Privacy Controls",
                       "Per-entry visibility from private to whole-family.")
            benefitRow("printer.fill", "Printable Reports",
                       "Generate clean PDFs for school, doctor, court.")
            benefitRow("archivebox.fill", "Family Legacy Archive",
                       "A long-term home for the memories that matter.")
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func benefitRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.title3)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            ForEach(FamoriaProduct.allCases, id: \.rawValue) { kind in
                pricingCard(for: kind)
            }
        }
    }

    private func pricingCard(for kind: FamoriaProduct) -> some View {
        let product = manager.product(kind)
        let isSelected = selectedProduct == kind
        return Button {
            selectedProduct = kind
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purple : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.purple).frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(kind.displayTitle).font(.headline)
                        if let chip = kind.savingsChip {
                            Text(chip)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    if let product {
                        Text("\(product.displayPrice) / \(kind == .monthly ? "month" : "year")")
                            .font(.subheadline).foregroundColor(.secondary)
                    } else {
                        Text(kind == .monthly ? "$6.99 / month" : "$59.99 / year")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.purple : Color.gray.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trial callout

    private var trialCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill").foregroundColor(.purple)
            Text("7-day free trial — cancel anytime.")
                .font(.footnote)
                .foregroundColor(.purple)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.10))
        .cornerRadius(10)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await manager.purchase(selectedProduct) }
            } label: {
                Group {
                    if manager.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(manager.currentStatus == .free
                             ? "Start free trial"
                             : "Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(LinearGradient(colors: [.purple, .pink],
                                           startPoint: .leading, endPoint: .trailing))
                .cornerRadius(14)
            }
            .disabled(manager.isPurchasing)

            Button {
                Task { await manager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
        }
    }

    private var legalDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subscriptions auto-renew until cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple ID Subscriptions.")
            HStack(spacing: 16) {
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://famoria.app/privacy")!)
            }
            .font(.caption.weight(.semibold))
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}

// MARK: - PaywallGate modifier

/// Convenience modifier: `.requiresPremium(...)` swaps the gated view for
/// an upsell card when the family is on the free tier and the user taps
/// to upgrade. Use it on premium-only screens (DocumentVault, Health
/// Center, advanced privacy, printable reports).
struct PaywallGate: ViewModifier {
    @EnvironmentObject var appState: AppState
    let featureName: String
    let featureBlurb: String
    let icon: String

    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if appState.entitlements.isPremium {
            content
        } else {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 84, height: 84)
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(.purple)
                }
                Text(featureName)
                    .font(.title3.bold())
                Text(featureBlurb)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    showPaywall = true
                } label: {
                    Text("Unlock with Famoria Plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(LinearGradient(colors: [.purple, .pink],
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showPaywall) {
                SubscriptionView()
                    .environmentObject(appState)
            }
        }
    }
}

extension View {
    func requiresPremium(
        featureName: String,
        featureBlurb: String,
        icon: String = "sparkles"
    ) -> some View {
        modifier(PaywallGate(featureName: featureName,
                              featureBlurb: featureBlurb,
                              icon: icon))
    }
}
