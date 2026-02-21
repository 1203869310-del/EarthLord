//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  挂单详情：库存校验 + 接受交易确认
//

import SwiftUI

struct TradeOfferDetailView: View {

    let offer: TradeOffer

    @ObservedObject private var inventory = InventoryManager.shared
    @State private var showConfirmAlert = false
    @State private var isAccepting = false
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    // 买家库存是否足够
    private var canAccept: Bool {
        offer.requestingItems.allSatisfy {
            inventory.getItemQuantity(name: $0.name) >= $0.quantity
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 发布者信息
                    publisherSection

                    // 提供物品
                    itemSection(
                        title: "他提供",
                        items: offer.offeringItems,
                        accentColor: ApocalypseTheme.success
                    )

                    // 换取物品
                    itemSection(
                        title: "他想要",
                        items: offer.requestingItems,
                        accentColor: ApocalypseTheme.warning
                    )

                    // 留言
                    if let msg = offer.message, !msg.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("备注", systemImage: "bubble.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("「\(msg)」")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .italic()
                        }
                        .padding(14)
                        .background(ApocalypseTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 库存校验
                    inventoryCheckSection

                    // 提示信息
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.danger)
                    }

                    if let success = successMessage {
                        Text(success)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    // 接受按钮
                    acceptButton
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("交易详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .alert("确认交易？", isPresented: $showConfirmAlert) {
            Button("确认交易", role: .destructive) { acceptOffer() }
            Button("取消", role: .cancel) {}
        } message: {
            let give = offer.requestingItems.map { "\($0.name)×\($0.quantity)" }.joined(separator: "、")
            let get  = offer.offeringItems.map  { "\($0.name)×\($0.quantity)" }.joined(separator: "、")
            Text("你将付出：\(give)\n你将获得：\(get)")
        }
    }

    // MARK: - Sections

    private var publisherSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(offer.ownerUsername.prefix(16)))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Label("剩余 \(offer.remainingTimeText)", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func itemSection(title: String, items: [TradeItem], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)

            ForEach(items) { item in
                TradeItemRow(item: item)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var inventoryCheckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你的库存")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            ForEach(offer.requestingItems) { item in
                let owned  = inventory.getItemQuantity(name: item.name)
                let enough = owned >= item.quantity

                HStack {
                    Text(item.name)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("需 \(item.quantity) / 有 \(owned)")
                        .font(.system(size: 12))
                        .foregroundColor(enough ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)

                    Image(systemName: enough ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(enough ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((enough ? Color.green : Color.red).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !canAccept {
                Text("物品不足，无法接受此交易")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var acceptButton: some View {
        Button(action: { showConfirmAlert = true }) {
            HStack(spacing: 8) {
                if isAccepting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.left.arrow.right")
                }

                Text(isAccepting ? "交易中…" : "接受交易")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canAccept && !isAccepting ? ApocalypseTheme.primary : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canAccept || isAccepting)
    }

    // MARK: - Actions

    private func acceptOffer() {
        isAccepting  = true
        errorMessage = nil

        Task {
            do {
                try await TradeManager.shared.acceptTradeOffer(offerId: offer.id)
                let names = offer.offeringItems.map { $0.name }.joined(separator: "、")
                successMessage = "交易成功！已获得 \(names)"
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isAccepting = false
        }
    }
}
