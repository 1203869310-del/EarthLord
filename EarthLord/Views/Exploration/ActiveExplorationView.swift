//
//  ActiveExplorationView.swift
//  EarthLord
//
//  实时探索界面 - 显示探索过程中的实时数据
//

import SwiftUI

struct ActiveExplorationView: View {

    // MARK: - Properties

    @ObservedObject var explorationManager = ExplorationManager.shared

    // MARK: - Computed

    /// 格式化的持续时间
    private var formattedDuration: String {
        let minutes = Int(explorationManager.duration) / 60
        let seconds = Int(explorationManager.duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("探索中...")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 统计卡片
            VStack(spacing: 16) {
                // 行走距离
                statRow(
                    icon: "figure.walk",
                    label: "行走距离",
                    value: String(format: "%.0f", explorationManager.totalDistance),
                    unit: "米",
                    color: .blue
                )

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 当前等级
                statRow(
                    icon: explorationManager.currentTier.iconName,
                    label: "当前等级",
                    value: explorationManager.currentTier.rawValue,
                    unit: "",
                    color: tierColor
                )

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 探索时长
                statRow(
                    icon: "clock.fill",
                    label: "探索时长",
                    value: formattedDuration,
                    unit: "",
                    color: .orange
                )

                if explorationManager.currentTier != .none {
                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.3))

                    // 预计奖励
                    HStack {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.green)
                            .frame(width: 30)

                        Text("预计奖励")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        Text("\(explorationManager.currentTier.itemCount) 件物品")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
            .padding(20)
            .background(ApocalypseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 等级提示
            if explorationManager.currentTier == .none {
                tipsView(
                    text: "继续走动以获得奖励",
                    subtext: "至少需要行走 200 米"
                )
            } else {
                let nextTier = getNextTier()
                if let next = nextTier {
                    tipsView(
                        text: "距离下一等级还需",
                        subtext: String(format: "%.0f 米", next.distance - explorationManager.totalDistance)
                    )
                }
            }

            Spacer()

            // 停止按钮
            stopButton
        }
        .padding(20)
        .background(ApocalypseTheme.background.ignoresSafeArea())
    }

    // MARK: - Stat Row

    /// 统计行
    private func statRow(
        icon: String,
        label: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30)

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Tips View

    /// 提示视图
    private func tipsView(text: String, subtext: String) -> some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(subtext)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(ApocalypseTheme.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stop Button

    /// 停止按钮
    private var stopButton: some View {
        Button(action: {
            explorationManager.stopExploration()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("结束探索")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(ApocalypseTheme.danger)
            )
            .shadow(color: ApocalypseTheme.danger.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Helpers

    /// 获取等级颜色
    private var tierColor: Color {
        switch explorationManager.currentTier.color {
        case "brown": return .brown
        case "gray": return .gray
        case "yellow": return .yellow
        case "cyan": return .cyan
        default: return ApocalypseTheme.primary
        }
    }

    /// 获取下一等级信息
    private func getNextTier() -> (tier: RewardTier, distance: Double)? {
        switch explorationManager.currentTier {
        case .none:
            return (.bronze, 200)
        case .bronze:
            return (.silver, 500)
        case .silver:
            return (.gold, 1000)
        case .gold:
            return (.diamond, 2000)
        case .diamond:
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    ActiveExplorationView()
}
