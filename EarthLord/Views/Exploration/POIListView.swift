//
//  POIListView.swift
//  EarthLord
//
//  POI 列表页面 - 显示附近的兴趣点
//

import SwiftUI

struct POIListView: View {

    // MARK: - State

    /// 所有POI数据（从假数据加载）
    @State private var allPOIs: [POI] = MockExplorationData.pois

    /// 当前选中的分类（nil表示全部）
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching = false

    /// 列表项出现动画控制
    @State private var showItems = false

    // MARK: - Computed

    /// 筛选后的POI列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return allPOIs.filter { $0.type == category }
        }
        return allPOIs
    }

    /// 已发现的POI数量
    private var discoveredCount: Int {
        allPOIs.filter { $0.status == .discovered }.count
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton

                // 筛选工具栏
                filterToolbar

                // POI列表
                if filteredPOIs.isEmpty {
                    emptyStateView
                } else {
                    poiListSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showItems = true
            }
        }
    }

    // MARK: - Status Bar

    /// 顶部状态栏
    private var statusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("GPS: 22.5400, 114.0600")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 统计图标
            Image(systemName: "map.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.primary.opacity(0.3))
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Button

    /// 搜索按钮
    private var searchButton: some View {
        Button(action: {
            performSearch()
        }) {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isSearching ? "搜索中..." : "搜索附近POI")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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
            .scaleEffect(isSearching ? 0.95 : 1.0)
        }
        .disabled(isSearching)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSearching)
    }

    /// 执行搜索
    private func performSearch() {
        withAnimation {
            isSearching = true
        }

        // 模拟网络请求1.5秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSearching = false
                // 模拟发现新POI（这里可以更新 allPOIs）
            }
        }
    }

    // MARK: - Filter Toolbar

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                filterButton(category: nil, label: "全部", icon: "circle.grid.3x3.fill")

                // 各类型按钮
                ForEach(POIType.allCases, id: \.self) { type in
                    filterButton(
                        category: type,
                        label: type.rawValue,
                        icon: type.iconName
                    )
                }
            }
        }
    }

    /// 筛选按钮
    private func filterButton(category: POIType?, label: String, icon: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(
                selectedCategory == category ? .white : ApocalypseTheme.textPrimary
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        selectedCategory == category ?
                            ApocalypseTheme.primary :
                            ApocalypseTheme.cardBackground
                    )
            )
        }
    }

    // MARK: - POI List

    /// POI列表区域
    private var poiListSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                NavigationLink(destination: POIDetailView(poi: poi)) {
                    POIRowView(poi: poi)
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 20)
                        .animation(
                            .easeOut(duration: 0.3).delay(Double(index) * 0.1),
                            value: showItems
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Empty State

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("没有找到该类型的地点")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试切换其他分类或搜索新的POI")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - POI Row View

/// POI 列表项视图
struct POIRowView: View {

    let poi: POI

    var body: some View {
        HStack(spacing: 16) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: poi.type.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(typeColor)
            }

            // 信息区域
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(poi.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 发现状态标签
                    if poi.status == .discovered {
                        statusBadge("已发现", color: .green)
                    }
                }

                HStack(spacing: 12) {
                    // 类型标签
                    Label(poi.type.rawValue, systemImage: "tag.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 物资状态
                    if poi.resourceStatus != .unknown {
                        Label(
                            poi.resourceStatus == .available ? "有物资" : "已清空",
                            systemImage: poi.resourceStatus == .available ? "cube.fill" : "cube"
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(
                            poi.resourceStatus == .available ?
                                Color.green :
                                ApocalypseTheme.textSecondary
                        )
                    }
                }
            }

            Spacer()

            // 箭头图标
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 类型颜色
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

    /// 状态徽章
    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIListView()
    }
}
