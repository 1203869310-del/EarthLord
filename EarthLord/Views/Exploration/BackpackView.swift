//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//

import SwiftUI

struct BackpackView: View {

    // MARK: - State

    /// 背包管理器
    @ObservedObject var inventoryManager = InventoryManager.shared

    /// 当前选中的分类（nil表示全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 搜索文字
    @State private var searchText = ""

    // MARK: - Computed

    /// 容量使用百分比
    private var capacityPercentage: Double {
        inventoryManager.capacityPercentage
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return .red
        } else if capacityPercentage > 0.7 {
            return .yellow
        } else {
            return .green
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var items = inventoryManager.items

        // 分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 容量状态卡
                capacityCard

                // 搜索框
                searchBar

                // 筛选工具栏
                filterToolbar

                // 物品列表
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemListSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
    }

    // MARK: - Capacity Card

    /// 容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("背包容量")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(String(format: "%.0f", inventoryManager.usedCapacity)) / \(String(format: "%.0f", inventoryManager.maxCapacity))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(capacityColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)

                    // 填充
                    Capsule()
                        .fill(capacityColor)
                        .frame(
                            width: geometry.size.width * min(capacityPercentage, 1.0),
                            height: 12
                        )
                        .animation(.spring(response: 0.5), value: capacityPercentage)
                }
            }
            .frame(height: 12)

            // 警告文字
            if capacityPercentage > 0.9 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))

                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Bar

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Filter Toolbar

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                categoryButton(category: nil, label: "全部", icon: "square.grid.2x2.fill")

                // 各分类按钮
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    categoryButton(
                        category: category,
                        label: category.rawValue,
                        icon: category.iconName
                    )
                }
            }
        }
    }

    /// 分类按钮
    private func categoryButton(category: ItemCategory?, label: String, icon: String) -> some View {
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

    // MARK: - Item List

    /// 物品列表区域
    private var itemListSection: some View {
        VStack(spacing: 12) {
            ForEach(filteredItems) { item in
                ItemRowView(item: item)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: filteredItems.count)
    }

    // MARK: - Empty State

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "bag" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(searchText.isEmpty ? "背包空空如也" : "没有找到相关物品")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            if searchText.isEmpty {
                Text("去探索收集物资吧")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Item Row View

/// 物品行视图
struct ItemRowView: View {

    let item: BackpackItem

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：类型图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: item.category.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(categoryColor)
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    rarityBadge
                }

                HStack(spacing: 12) {
                    // 数量
                    Label("x\(item.quantity)", systemImage: "number")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 重量
                    Label("\(String(format: "%.1f", item.weight))kg", systemImage: "scalemass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如有）
                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // 右侧：操作按钮
            VStack(spacing: 8) {
                actionButton(icon: "checkmark.circle", label: "使用") {
                    print("使用 \(item.name)")
                }

                actionButton(icon: "tray.fill", label: "存储") {
                    print("存储 \(item.name)")
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 分类颜色
    private var categoryColor: Color {
        switch item.category.color {
        case "orange": return .orange
        case "blue": return .blue
        case "brown": return .brown
        case "gray": return .gray
        case "red": return .red
        default: return ApocalypseTheme.primary
        }
    }

    /// 稀有度徽章
    private var rarityBadge: some View {
        let color: Color = {
            switch item.rarity.color {
            case "gray": return .gray
            case "green": return .green
            case "blue": return .blue
            case "purple": return .purple
            default: return .gray
            }
        }()

        return Text(item.rarity.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    /// 操作按钮
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ApocalypseTheme.primary.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    BackpackView()
}
