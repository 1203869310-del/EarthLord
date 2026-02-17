//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果弹窗页面
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - Properties

    let result: ExplorationResult

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss

    // MARK: - State

    /// 距离数字动画值
    @State private var animatedDistance: Double = 0

    /// 面积数字动画值
    @State private var animatedArea: Double = 0

    /// 是否显示奖励物品
    @State private var showRewards = false

    /// 已显示的奖励索引
    @State private var visibleRewardIndices: Set<Int> = []

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题
                achievementHeader

                // 奖励等级徽章
                rewardTierBadge

                // 统计数据卡片
                statsCard

                // 奖励物品卡片
                rewardsCard

                // 确认按钮
                confirmButton
            }
            .padding(20)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Achievement Header

    /// 成就标题
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "map.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .scaleEffect(showRewards ? 1.0 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showRewards)

            // 大文字
            Text("探索完成！")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("你在末世中又向前迈进了一步")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Reward Tier Badge

    /// 奖励等级徽章
    private var rewardTierBadge: some View {
        VStack(spacing: 12) {
            // 等级图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tierColor.opacity(0.3),
                                tierColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: result.rewardTier.iconName)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(tierColor)
            }
            .scaleEffect(showRewards ? 1.0 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showRewards)

            // 等级名称
            Text(result.rewardTier.rawValue)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(tierColor)

            // 物品数量提示
            if result.rewardTier != .none {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 14))

                    Text("获得 \(result.rewardTier.itemCount) 件物品")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Text("距离太短，继续努力！")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tierColor.opacity(0.3), lineWidth: 2)
                )
        )
        .opacity(showRewards ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.3), value: showRewards)
    }

    /// 获取等级颜色
    private var tierColor: Color {
        switch result.rewardTier.color {
        case "gray": return .gray
        case "brown": return .brown
        case "yellow": return .yellow
        case "cyan": return .cyan
        default: return ApocalypseTheme.primary
        }
    }

    // MARK: - Stats Card

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("统计数据")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 行走距离
            statRow(
                icon: "figure.walk",
                label: "行走距离",
                current: animatedDistance,
                total: result.distance.total,
                rank: result.distance.rank,
                unit: "m"
            )

            Divider()

            // 探索面积
            statRow(
                icon: "map",
                label: "探索面积",
                current: animatedArea,
                total: result.area.total,
                rank: result.area.rank,
                unit: "m²"
            )

            Divider()

            // 探索时长
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 30)

                Text("探索时长")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(result.duration) 分钟")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// 统计行
    private func statRow(
        icon: String,
        label: String,
        current: Double,
        total: Double,
        rank: Int,
        unit: String
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 30)

                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 排名徽章
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))

                    Text("#\(rank)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .clipShape(Capsule())
            }

            HStack {
                Text("本次")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(String(format: "%.0f", current)) \(unit)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.primary)

                Spacer()

                Text("累计")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(String(format: "%.0f", total)) \(unit)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.leading, 30)
        }
    }

    // MARK: - Rewards Card

    /// 奖励物品卡片
    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)

                Text("获得物品")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 物品列表
            VStack(spacing: 12) {
                ForEach(Array(result.rewards.enumerated()), id: \.element.id) { index, reward in
                    rewardRow(reward: reward, index: index)
                        .opacity(visibleRewardIndices.contains(index) ? 1 : 0)
                        .offset(y: visibleRewardIndices.contains(index) ? 0 : 20)
                }
            }

            // 底部提示
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)

                Text("已添加到背包")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .opacity(showRewards ? 1 : 0)
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// 奖励物品行
    private func rewardRow(reward: RewardItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor(for: reward.category).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: reward.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(categoryColor(for: reward.category))
            }

            // 名称、数量和稀有度
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(reward.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(reward.quantity)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 稀有度标签
                rarityBadge(for: reward.rarity)
            }

            Spacer()

            // 对勾图标
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .scaleEffect(visibleRewardIndices.contains(index) ? 1.0 : 0.5)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.5).delay(0.1),
                    value: visibleRewardIndices.contains(index)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(rarityColor(for: reward.rarity).opacity(0.3), lineWidth: 1)
                )
        )
    }

    /// 稀有度徽章
    private func rarityBadge(for rarity: Rarity) -> some View {
        Text(rarity.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(rarityColor(for: rarity))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(rarityColor(for: rarity).opacity(0.2))
            .clipShape(Capsule())
    }

    /// 获取稀有度颜色
    private func rarityColor(for rarity: Rarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .legendary: return .orange
        case .rare: return .blue
        case .epic: return .purple
        }
    }

    /// 获取分类颜色
    private func categoryColor(for category: ItemCategory) -> Color {
        switch category.color {
        case "orange": return .orange
        case "blue": return .blue
        case "brown": return .brown
        case "gray": return .gray
        case "red": return .red
        default: return ApocalypseTheme.primary
        }
    }

    // MARK: - Confirm Button

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            Text("确认")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 10)
    }

    // MARK: - Animations

    /// 启动所有动画
    private func startAnimations() {
        // 数字跳动动画
        withAnimation(.easeOut(duration: 1.0)) {
            animatedDistance = result.distance.current
            animatedArea = result.area.current
        }

        // 延迟显示奖励
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showRewards = true
            }

            // 奖励物品依次出现
            for (index, _) in result.rewards.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(index) * 0.2) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        _ = visibleRewardIndices.insert(index)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.explorationResult)
}
