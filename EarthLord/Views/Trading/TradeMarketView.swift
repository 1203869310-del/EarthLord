//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场：显示其他玩家的活跃挂单
//

import SwiftUI

struct TradeMarketView: View {

    @ObservedObject private var tradeManager = TradeManager.shared
    @State private var selectedOffer: TradeOffer? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if tradeManager.isLoading && tradeManager.availableOffers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .tint(ApocalypseTheme.primary)

                } else if tradeManager.availableOffers.isEmpty {
                    emptyState

                } else {
                    ForEach(tradeManager.availableOffers) { offer in
                        OfferCard(offer: offer, isOwner: false)
                            .onTapGesture { selectedOffer = offer }
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.background)
        .task { await loadOffers() }
        .refreshable { await loadOffers() }
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(offer: offer)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无可用挂单")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("稍后再来，或等待其他玩家发布")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func loadOffers() async {
        do {
            try await tradeManager.loadAvailableOffers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    TradeMarketView()
}
