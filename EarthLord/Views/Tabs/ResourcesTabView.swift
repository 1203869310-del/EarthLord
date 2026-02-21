//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - State

    /// 当前选中的分段
    @State private var selectedSegment = 0

    /// 交易开关状态（假数据）
    @State private var tradingEnabled = false

    // MARK: - Segments

    private enum Segment: Int, CaseIterable {
        case poi = 0
        case backpack = 1
        case purchased = 2
        case territory = 3
        case trading = 4

        var title: String {
            switch self {
            case .poi: return "POI"
            case .backpack: return "背包"
            case .purchased: return "已购"
            case .territory: return "领地"
            case .trading: return "交易"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部栏
                topBar

                // 分段选择器
                segmentedControl

                // 内容区域
                contentArea
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: - Top Bar

    /// 顶部栏
    private var topBar: some View {
        HStack {
            // 标题
            Text("资源")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 交易开关
            HStack(spacing: 8) {
                Text("交易")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Toggle("", isOn: $tradingEnabled)
                    .labelsHidden()
                    .tint(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Segmented Control

    /// 分段选择器
    private var segmentedControl: some View {
        Picker("", selection: $selectedSegment) {
            ForEach(Segment.allCases, id: \.rawValue) { segment in
                Text(segment.title)
                    .tag(segment.rawValue)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Content Area

    /// 内容区域
    private var contentArea: some View {
        Group {
            switch Segment(rawValue: selectedSegment) {
            case .poi:
                POIListView()

            case .backpack:
                BackpackView()

            case .purchased:
                placeholderView(icon: "bag.fill", text: "已购功能开发中")

            case .territory:
                placeholderView(icon: "map.fill", text: "领地功能开发中")

            case .trading:
                TradingView()

            case .none:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSegment)
    }

    // MARK: - Placeholder View

    /// 占位视图
    private func placeholderView(icon: String, text: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("敬请期待...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
