//
//  MyOffersView.swift
//  EarthLord
//
//  我的挂单列表
//

import SwiftUI

struct MyOffersView: View {

    @ObservedObject private var tradeManager = TradeManager.shared
    @State private var showCancelAlert = false
    @State private var selectedOfferId: UUID? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if tradeManager.isLoading && tradeManager.myOffers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .tint(ApocalypseTheme.primary)

                } else if tradeManager.myOffers.isEmpty {
                    emptyState

                } else {
                    ForEach(tradeManager.myOffers) { offer in
                        OfferCard(offer: offer, isOwner: true) {
                            selectedOfferId = offer.id
                            showCancelAlert = true
                        }
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
        .alert("确认取消挂单？", isPresented: $showCancelAlert) {
            Button("取消挂单", role: .destructive) { cancelOffer() }
            Button("保留", role: .cancel) {}
        } message: {
            Text("物品将退回背包，此操作无法撤销。")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无挂单")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("点击右上角「发布」创建第一个挂单")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func loadOffers() async {
        do {
            try await tradeManager.loadMyOffers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelOffer() {
        guard let id = selectedOfferId else { return }
        Task {
            do {
                try await tradeManager.cancelTradeOffer(offerId: id)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MyOffersView()
}
