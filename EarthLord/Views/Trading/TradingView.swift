//
//  TradingView.swift
//  EarthLord
//
//  交易功能主容器，以及通用子组件：TradeItemRow、OfferCard
//

import SwiftUI

// MARK: - 交易主视图

struct TradingView: View {

    @State private var selectedTab = 0
    @State private var showCreateSheet = false
    @ObservedObject private var tradeManager = TradeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 顶部控制栏
            HStack(spacing: 12) {
                Picker("", selection: $selectedTab) {
                    Text("我的挂单").tag(0)
                    Text("市场").tag(1)
                    Text("历史").tag(2)
                }
                .pickerStyle(.segmented)

                if selectedTab == 0 {
                    Button(action: { showCreateSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("发布")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ApocalypseTheme.primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.background)

            // 内容区域
            Group {
                switch selectedTab {
                case 0: MyOffersView()
                case 1: TradeMarketView()
                case 2: TradeHistoryView()
                default: EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showCreateSheet) {
            CreateTradeOfferView()
        }
    }
}

// MARK: - 通用物品行

struct TradeItemRow: View {

    let item: TradeItem
    let onDelete: (() -> Void)?

    init(item: TradeItem, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 名称 + 数量
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("×\(item.quantity)")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 删除按钮（可选）
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    private var iconName: String {
        InventoryManager.shared.itemDefinitions
            .first(where: { $0.name == item.name })?.category.iconName ?? "cube.fill"
    }

    private var iconColor: Color {
        let colorStr = InventoryManager.shared.itemDefinitions
            .first(where: { $0.name == item.name })?.category.color ?? "gray"
        return colorFromString(colorStr)
    }
}

// MARK: - 通用挂单卡片

struct OfferCard: View {

    let offer: TradeOffer
    let isOwner: Bool
    let onCancel: (() -> Void)?

    init(offer: TradeOffer, isOwner: Bool, onCancel: (() -> Void)? = nil) {
        self.offer = offer
        self.isOwner = isOwner
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：状态徽章 + 时间/发布者
            HStack {
                statusBadge

                Spacer()

                if offer.status == .active {
                    Label(offer.remainingTimeText, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                if !isOwner {
                    Text(String(offer.ownerUsername.prefix(8)) + "…")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // 提供物品
            itemGroup(label: "提供", items: offer.offeringItems)

            // 换取物品
            itemGroup(label: "换取", items: offer.requestingItems)

            // 留言
            if let msg = offer.message, !msg.isEmpty {
                Text("「\(msg)」")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .italic()
            }

            // 已完成时显示接受者
            if offer.status == .completed, let buyer = offer.completedByUsername, !buyer.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.success)
                    Text("已被")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(String(buyer.prefix(12)))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("接受")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 取消按钮（仅自己的 active 挂单）
            if isOwner, offer.status == .active, let onCancel {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Text("取消挂单")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.danger)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(ApocalypseTheme.danger.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch offer.status {
            case .active:    return ("等待中", .blue)
            case .completed: return ("已完成", .green)
            case .cancelled: return ("已取消", .gray)
            case .expired:   return ("已过期", .orange)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func itemGroup(label: String, items: [TradeItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            ForEach(items) { item in
                TradeItemRow(item: item)
            }
        }
    }
}

// MARK: - TradeOffer 剩余时间

extension TradeOffer {
    var remainingTimeText: String {
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining <= 0 { return "已过期" }
        let hours = remaining / 3600
        if hours < 1 {
            return "\(Int(remaining / 60))分钟"
        } else if hours < 24 {
            return "\(Int(hours))小时"
        } else {
            return "\(Int(hours / 24))天"
        }
    }
}

// MARK: - 颜色辅助（全局）

func colorFromString(_ colorStr: String) -> Color {
    switch colorStr {
    case "orange": return .orange
    case "blue":   return .blue
    case "brown":  return .brown
    case "gray":   return .gray
    case "red":    return .red
    default:       return ApocalypseTheme.primary
    }
}

// MARK: - Preview

#Preview {
    TradingView()
}
