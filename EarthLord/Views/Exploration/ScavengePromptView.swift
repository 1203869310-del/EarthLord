//
//  ScavengePromptView.swift
//  EarthLord
//
//  搜刮提示弹窗 - 玩家进入 POI 50 米范围时显示
//

import SwiftUI

// MARK: - 搜刮提示弹窗

/// 搜刮提示弹窗
/// 当玩家进入 POI 50 米范围内时显示，点击搜刮获得物品
struct ScavengePromptView: View {

    // MARK: - Properties

    /// POI 信息
    let poi: POI

    /// 距离（米）
    let distance: Double

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 关闭回调
    let onDismiss: () -> Void

    // MARK: - State

    /// 按钮动画状态
    @State private var isButtonPressed = false

    /// 出现动画
    @State private var showContent = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 拖动条
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            VStack(spacing: 16) {
                // 顶部信息栏
                HStack(spacing: 12) {
                    // POI 图标
                    ZStack {
                        Circle()
                            .fill(typeColor.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: poi.type.iconName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(typeColor)
                    }

                    // POI 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(poi.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            // 类型标签
                            Text(poi.type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            // 距离
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text("\(Int(distance))米")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(ApocalypseTheme.primary)
                        }
                    }

                    Spacer()

                    // 关闭按钮
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // 分割线
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)

                // 搜刮按钮
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isButtonPressed = true
                    }
                    // 延迟执行搜刮
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onScavenge()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))

                        Text("搜刮此地点")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    .scaleEffect(isButtonPressed ? 0.95 : 1.0)
                }

                // 奖励提示
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12))
                    Text("预计获得: \(poi.type.rewardTier.rawValue) 奖励")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
        )
        .offset(y: showContent ? 0 : 200)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }

    // MARK: - Computed

    /// POI 类型颜色
    private var typeColor: Color {
        switch poi.type.color {
        case "red": return .red
        case "green": return .green
        case "gray": return .gray
        case "purple": return .purple
        case "orange": return .orange
        default: return ApocalypseTheme.primary
        }
    }
}

// MARK: - 搜刮结果弹窗

/// 搜刮结果弹窗
/// 显示搜刮获得的物品
struct ScavengeResultView: View {

    // MARK: - Properties

    /// 搜刮结果
    let result: ScavengeResult

    /// 关闭回调
    let onDismiss: () -> Void

    // MARK: - State

    /// 物品出现动画
    @State private var visibleRewardIndices: Set<Int> = []

    /// 内容出现动画
    @State private var showContent = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [typeColor.opacity(0.8), typeColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                // 图标和标题
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)

                    Text("搜刮成功！")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // 内容区域
            VStack(spacing: 20) {
                // POI 信息
                HStack(spacing: 12) {
                    Image(systemName: result.poi.type.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(typeColor)

                    Text(result.poi.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text(result.formattedTime)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 分割线
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)

                // 获得物品标题
                HStack {
                    Text("获得物品")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(result.rewards.count) 件")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 物品列表
                VStack(spacing: 12) {
                    ForEach(Array(result.rewards.enumerated()), id: \.element.id) { index, reward in
                        if visibleRewardIndices.contains(index) {
                            RewardItemRow(reward: reward)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }

                // 确认按钮
                Button(action: onDismiss) {
                    Text("确认")
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
        .padding(20)
        .scaleEffect(showContent ? 1 : 0.8)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            // 内容出现动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }

            // 物品依次出现
            for index in 0..<result.rewards.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        _ = visibleRewardIndices.insert(index)
                    }
                }
            }
        }
    }

    // MARK: - Computed

    /// POI 类型颜色
    private var typeColor: Color {
        switch result.poi.type.color {
        case "red": return .red
        case "green": return .green
        case "gray": return .gray
        case "purple": return .purple
        case "orange": return .orange
        default: return ApocalypseTheme.primary
        }
    }
}

// MARK: - 奖励物品行

/// 奖励物品行
struct RewardItemRow: View {

    let reward: RewardItem

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(rarityColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: reward.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(rarityColor)
            }

            // 名称和稀有度
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(reward.rarity.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(rarityColor)
            }

            Spacer()

            // 数量
            Text("x\(reward.quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch reward.rarity.color {
        case "gray": return .gray
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview("搜刮提示") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            ScavengePromptView(
                poi: MockExplorationData.pois[0],
                distance: 35,
                onScavenge: {},
                onDismiss: {}
            )
        }
    }
}

#Preview("搜刮结果") {
    ZStack {
        Color.black.opacity(0.5).ignoresSafeArea()

        ScavengeResultView(
            result: ScavengeResult(
                poi: MockExplorationData.pois[0],
                rewards: [
                    RewardItem(name: "矿泉水", quantity: 3, iconName: "drop.fill", category: .water, rarity: .common),
                    RewardItem(name: "绷带", quantity: 2, iconName: "cross.fill", category: .medical, rarity: .common),
                    RewardItem(name: "罐头食品", quantity: 1, iconName: "fork.knife", category: .food, rarity: .rare)
                ],
                timestamp: Date()
            ),
            onDismiss: {}
        )
    }
}
