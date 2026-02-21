//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史记录列表
//

import SwiftUI

// MARK: - 交易历史列表

struct TradeHistoryView: View {

    @ObservedObject private var tradeManager = TradeManager.shared
    @State private var ratingTarget: TradeHistory? = nil
    @State private var claimingId: UUID? = nil
    @State private var errorMessage: String? = nil

    private var currentUserId: UUID? { AuthManager.shared.currentUserId }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if tradeManager.isLoading && tradeManager.tradeHistory.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .tint(ApocalypseTheme.primary)

                } else if tradeManager.tradeHistory.isEmpty {
                    emptyState

                } else {
                    ForEach(tradeManager.tradeHistory) { record in
                        HistoryCard(
                            record: record,
                            currentUserId: currentUserId,
                            isClaimLoading: claimingId == record.id,
                            onRate:  { ratingTarget = record },
                            onClaim: { claimItems(record: record) }
                        )
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
        .task { await loadHistory() }
        .refreshable { await loadHistory() }
        .sheet(item: $ratingTarget) { record in
            RatingSheet(record: record, currentUserId: currentUserId) { rating, comment in
                Task {
                    do {
                        try await tradeManager.rateTrade(
                            historyId: record.id,
                            rating: rating,
                            comment: comment
                        )
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无交易记录")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("完成一笔交易后，记录会显示在这里")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func loadHistory() async {
        do {
            try await tradeManager.loadTradeHistory()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func claimItems(record: TradeHistory) {
        claimingId = record.id
        Task {
            do {
                try await tradeManager.claimSellerItems(historyId: record.id)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            claimingId = nil
        }
    }
}

// MARK: - 历史记录卡片

private struct HistoryCard: View {

    let record: TradeHistory
    let currentUserId: UUID?
    let isClaimLoading: Bool
    let onRate: () -> Void
    let onClaim: () -> Void

    private var isSeller: Bool { record.sellerId == currentUserId }

    private var counterpartName: String {
        isSeller ? record.buyerUsername : record.sellerUsername
    }

    private var completedText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: record.completedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack {
                Text("与 \(String(counterpartName.prefix(12))) 的交易")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text(completedText)
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Divider().background(Color.white.opacity(0.1))

            // 物品交换（给出 ↔ 获得）
            HStack(alignment: .top, spacing: 12) {
                // 给出
                VStack(alignment: .leading, spacing: 4) {
                    Text("给出")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(gaveItems) { item in
                        Text("\(item.name) ×\(item.quantity)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.top, 14)

                // 获得
                VStack(alignment: .leading, spacing: 4) {
                    Text("获得")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(gotItems) { item in
                        Text("\(item.name) ×\(item.quantity)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Color.white.opacity(0.1))

            // 评价区
            HStack(spacing: 0) {
                ratingView(
                    label: "我的评价",
                    rating: isSeller ? record.sellerRating : record.buyerRating,
                    comment: isSeller ? record.sellerComment : record.buyerComment,
                    canRate: true
                )

                Divider()
                    .frame(height: 50)
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 8)

                ratingView(
                    label: "对方评价",
                    rating: isSeller ? record.buyerRating : record.sellerRating,
                    comment: isSeller ? record.buyerComment : record.sellerComment,
                    canRate: false
                )
            }

            // 卖家领取按钮
            if isSeller && !record.sellerClaimed {
                Button(action: onClaim) {
                    HStack(spacing: 6) {
                        if isClaimLoading {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(.white)
                        } else {
                            Image(systemName: "gift.fill")
                        }

                        Text(isClaimLoading ? "领取中…" : "领取物品")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.success)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isClaimLoading)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 卖家给出 offered，买家给出 requested
    private var gaveItems: [TradeItem] {
        isSeller ? record.itemsExchanged.offered : record.itemsExchanged.requested
    }

    private var gotItems: [TradeItem] {
        isSeller ? record.itemsExchanged.requested : record.itemsExchanged.offered
    }

    @ViewBuilder
    private func ratingView(
        label: String,
        rating: Int?,
        comment: String?,
        canRate: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            if let r = rating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= r ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }

                if let c = comment, !c.isEmpty {
                    Text(c)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(2)
                }

            } else if canRate {
                Button(action: onRate) {
                    Text("去评价")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                Text("未评价")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 评价 Sheet

private struct RatingSheet: View {

    let record: TradeHistory
    let currentUserId: UUID?
    let onSubmit: (Int, String?) -> Void

    @State private var rating = 0
    @State private var comment = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 星评
                VStack(spacing: 12) {
                    Text("为这笔交易评分")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { i in
                            Button(action: { rating = i }) {
                                Image(systemName: i <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundColor(i <= rating ? .yellow : ApocalypseTheme.textSecondary)
                            }
                        }
                    }

                    if rating > 0 {
                        Text(ratingLabel(rating))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 评价文字
                VStack(alignment: .leading, spacing: 8) {
                    Text("评价内容（可选）")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("写下你的感受…", text: $comment, axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(ApocalypseTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                // 提交
                Button(action: submitRating) {
                    Text("提交评价")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(rating > 0 ? ApocalypseTheme.primary : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(rating == 0)
            }
            .padding(24)
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("交易评价")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    private func ratingLabel(_ r: Int) -> String {
        switch r {
        case 1: return "非常差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "满意"
        case 5: return "非常满意"
        default: return ""
        }
    }

    private func submitRating() {
        onSubmit(rating, comment.isEmpty ? nil : comment)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    TradeHistoryView()
}
