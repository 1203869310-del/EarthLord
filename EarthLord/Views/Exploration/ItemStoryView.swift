//
//  ItemStoryView.swift
//  EarthLord
//
//  物品故事弹窗 - 展示 AI 生成物品的背景故事
//

import SwiftUI

// MARK: - 物品故事弹窗

/// 物品故事弹窗
/// 展示 AI 生成物品的名称、稀有度和背景故事
struct ItemStoryView: View {

    // MARK: - Properties

    /// 奖励物品
    let reward: RewardItem

    /// 关闭回调
    let onDismiss: () -> Void

    // MARK: - State

    /// 出现动画
    @State private var showContent = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // 内容卡片
            VStack(spacing: 0) {
                // 顶部装饰
                ZStack {
                    // 背景渐变
                    LinearGradient(
                        colors: [rarityColor.opacity(0.8), rarityColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 100)

                    // 图标
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 60, height: 60)

                            Image(systemName: reward.iconName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // AI 标识
                        if reward.isAIGenerated {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("AI 生成")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                    }
                }

                // 内容区域
                VStack(spacing: 16) {
                    // 物品名称
                    Text(reward.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    // 稀有度和数量
                    HStack(spacing: 16) {
                        // 稀有度标签
                        HStack(spacing: 4) {
                            Circle()
                                .fill(rarityColor)
                                .frame(width: 8, height: 8)
                            Text(reward.rarity.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(rarityColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(rarityColor.opacity(0.15))
                        )

                        // 分类
                        Text(reward.category.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 数量
                        Text("x\(reward.quantity)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    // 分割线
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // 背景故事
                    if let story = reward.story, !story.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 12))
                                Text("背景故事")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(story)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                    }

                    // 关闭按钮
                    Button(action: dismiss) {
                        Text("确定")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(ApocalypseTheme.primary)
                            )
                    }
                }
                .padding(20)
            }
            .background(ApocalypseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(24)
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }

    // MARK: - Methods

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    // MARK: - Computed

    /// 稀有度颜色
    private var rarityColor: Color {
        switch reward.rarity.color {
        case "gray": return .gray
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview("物品故事") {
    ItemStoryView(
        reward: RewardItem(
            name: "老张的最后晚餐",
            quantity: 1,
            iconName: "fork.knife",
            category: .food,
            rarity: .rare,
            story: "在这座废弃超市的角落里，你发现了一个保存完好的午餐盒。盒盖上用马克笔写着'老张'两个字。里面的食物早已变质，但密封的罐头依然完好。这或许是某个幸存者最后的储备...",
            isAIGenerated: true
        ),
        onDismiss: {}
    )
}

#Preview("普通物品") {
    ItemStoryView(
        reward: RewardItem(
            name: "矿泉水",
            quantity: 3,
            iconName: "drop.fill",
            category: .water,
            rarity: .common
        ),
        onDismiss: {}
    )
}
