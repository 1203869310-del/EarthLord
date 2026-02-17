//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - Properties

    let poi: POI

    // MARK: - State

    /// 是否显示探索结果页
    @State private var showExplorationResult = false

    // MARK: - Computed

    /// 假数据：距离
    private var distance: Double {
        350.0
    }

    /// POI类型颜色
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

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    /// 是否可以搜寻
    private var canScavenge: Bool {
        poi.resourceStatus != .depleted
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部大图区域
                headerSection

                // 内容区域
                VStack(spacing: 20) {
                    // 信息卡片
                    infoCard

                    // 操作按钮区域
                    actionButtons
                }
                .padding(16)
            }
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(result: MockExplorationData.explorationResult)
        }
    }

    // MARK: - Header Section

    /// 顶部大图区域
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 背景渐变
            LinearGradient(
                colors: [
                    typeColor.opacity(0.8),
                    typeColor.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            // 大图标
            Image(systemName: poi.type.iconName)
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 80)

            // 底部遮罩 + 名称
            VStack(spacing: 8) {
                Text(poi.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(poi.type.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Info Card

    /// 信息卡片
    private var infoCard: some View {
        VStack(spacing: 16) {
            // 距离
            infoRow(
                icon: "location.fill",
                label: "距离",
                value: "\(String(format: "%.0f", distance))米",
                color: .blue
            )

            Divider()

            // 物资状态
            infoRow(
                icon: poi.resourceStatus == .available ? "cube.fill" : "cube",
                label: "物资状态",
                value: poi.resourceStatus == .available ? "有物资" : "已清空",
                color: poi.resourceStatus == .available ? .green : .gray
            )

            Divider()

            // 危险等级
            infoRow(
                icon: "exclamationmark.triangle.fill",
                label: "危险等级",
                value: poi.dangerLevel.displayName,
                color: dangerColor
            )

            Divider()

            // 来源
            infoRow(
                icon: "mappin.circle.fill",
                label: "来源",
                value: poi.source,
                color: .purple
            )
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// 信息行
    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }

            // 标签
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - Action Buttons

    /// 操作按钮区域
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 主按钮：搜寻此POI
            Button(action: {
                showExplorationResult = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))

                    Text("搜寻此POI")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canScavenge ?
                            [Color.orange, Color.orange.opacity(0.8)] :
                            [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(
                    color: canScavenge ? Color.orange.opacity(0.3) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .disabled(!canScavenge)

            // 两个小按钮
            HStack(spacing: 12) {
                secondaryButton(icon: "checkmark.circle", label: "标记已发现") {
                    print("标记已发现")
                }

                secondaryButton(icon: "cube", label: "标记无物资") {
                    print("标记无物资")
                }
            }
        }
    }

    /// 次要按钮
    private func secondaryButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(ApocalypseTheme.primary, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.pois[0])
    }
}
