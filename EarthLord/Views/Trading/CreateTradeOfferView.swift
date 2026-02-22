//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  发布挂单表单
//

import SwiftUI

// MARK: - 选择器目标（文件级，供 CreateTradeOfferView 和 ItemPickerSheet 共用）

fileprivate enum TradePickerTarget: String, Identifiable {
    case offering   // 我要出的物品
    case requesting // 我想要的物品

    var id: String { rawValue }

    var title: String {
        self == .offering ? "选择提供的物品" : "选择想要的物品"
    }
}

// MARK: - 发布挂单视图

struct CreateTradeOfferView: View {

    @State private var offeringItems:   [TradeItem] = []
    @State private var requestingItems: [TradeItem] = []
    @State private var expiresInHours: Double = 24
    @State private var message = ""
    @State private var showPickerFor: TradePickerTarget? = nil
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert = false
    @Environment(\.dismiss) private var dismiss

    private let hourOptions: [(Double, String)] = [
        (1, "1小时"), (6, "6小时"), (12, "12小时"),
        (24, "24小时"), (48, "48小时"), (72, "72小时")
    ]

    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 提供物品
                    itemSection(
                        title: "我要出的物品",
                        icon: "arrow.up.circle.fill",
                        iconColor: ApocalypseTheme.warning,
                        items: $offeringItems,
                        target: .offering
                    )

                    // 想要物品
                    itemSection(
                        title: "我想要的物品",
                        icon: "arrow.down.circle.fill",
                        iconColor: ApocalypseTheme.success,
                        items: $requestingItems,
                        target: .requesting
                    )

                    // 有效期
                    expirySection

                    // 留言
                    messageSection

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("发布挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(ApocalypseTheme.primary)
                        } else {
                            Text("发布")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(
                                    canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary
                                )
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .alert("发布成功", isPresented: $showSuccessAlert) {
                Button("查看挂单") { dismiss() }
            } message: {
                Text("挂单已发布，等待其他玩家接受。")
            }
            .sheet(item: $showPickerFor) { target in
                ItemPickerSheet(target: target) { item in
                    switch target {
                    case .offering:   upsertItem(item, in: &offeringItems)
                    case .requesting: upsertItem(item, in: &requestingItems)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private func itemSection(
        title: String,
        icon: String,
        iconColor: Color,
        items: Binding<[TradeItem]>,
        target: TradePickerTarget
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            if items.wrappedValue.isEmpty {
                Text("尚未添加物品")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(items.wrappedValue) { item in
                    TradeItemRow(item: item) {
                        items.wrappedValue.removeAll { $0.name == item.name }
                    }
                }
            }

            Button(action: { showPickerFor = target }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                    Text("添加物品")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var expirySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.info)
                Text("有效期")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(hourOptions, id: \.0) { (hours, label) in
                        Button(action: { expiresInHours = hours }) {
                            Text(label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(
                                    expiresInHours == hours ? .white : ApocalypseTheme.textPrimary
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        expiresInHours == hours
                                        ? ApocalypseTheme.primary
                                        : ApocalypseTheme.background
                                    )
                                )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("留言（可选）")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            TextField("写点什么…", text: $message, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(2...4)
                .padding(10)
                .background(ApocalypseTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func upsertItem(_ item: TradeItem, in list: inout [TradeItem]) {
        if let idx = list.firstIndex(where: { $0.name == item.name }) {
            list[idx] = item
        } else {
            list.append(item)
        }
    }

    private func submit() {
        isSubmitting  = true
        errorMessage  = nil

        Task {
            do {
                try await TradeManager.shared.createTradeOffer(
                    offering: offeringItems,
                    requesting: requestingItems,
                    expiresInHours: expiresInHours,
                    message: message.isEmpty ? nil : message
                )
                showSuccessAlert = true
            } catch TradeError.insufficientItems(let missing) {
                let desc = missing.map { "\($0.key) 还需 \($0.value)" }.joined(separator: "，")
                errorMessage = "物品不足：\(desc)"
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - 物品选择器 Sheet

private struct ItemPickerSheet: View {

    let target: TradePickerTarget
    let onSelect: (TradeItem) -> Void

    // 选中一个物品后跳转到数量选择
    private struct QuantityItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let maxQty: Int
    }

    @ObservedObject private var inventory = InventoryManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory? = nil
    @State private var quantityItem: QuantityItem? = nil
    @State private var showingQuantityPicker = false
    @Environment(\.dismiss) private var dismissSheet

    // 根据模式返回可选物品列表
    private var sourceItems: [(name: String, available: Int)] {
        if target == .offering {
            return inventory.items
                .filter { $0.quantity > 0 }
                .filter { selectedCategory == nil || $0.category == selectedCategory }
                .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                .map { ($0.name, $0.quantity) }
        } else {
            return inventory.itemDefinitions
                .filter { selectedCategory == nil || $0.category == selectedCategory }
                .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                .map { ($0.name, 99) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    TextField("搜索物品…", text: $searchText)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 分类筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterChip(category: nil, label: "全部")
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            filterChip(category: cat, label: cat.rawValue)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)

                // 物品列表
                if sourceItems.isEmpty {
                    Spacer()
                    Text(searchText.isEmpty ? "没有可选物品" : "没有匹配的物品")
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                } else {
                    List(sourceItems, id: \.name) { item in
                        HStack(spacing: 12) {
                            itemIcon(name: item.name)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                if target == .offering {
                                    Text("背包: \(item.available)")
                                        .font(.system(size: 12))
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }

                            Spacer()

                            Button("选择") {
                                quantityItem = QuantityItem(
                                    name: item.name,
                                    maxQty: item.available
                                )
                                showingQuantityPicker = true
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    }
                    .listStyle(.plain)
                    .background(ApocalypseTheme.background)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismissSheet() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            // 导航到数量选择页
            .navigationDestination(isPresented: $showingQuantityPicker) {
                if let qItem = quantityItem {
                    QuantityPickerView(
                        itemName: qItem.name,
                        maxQty: qItem.maxQty,
                        isInventoryBound: target == .offering
                    ) { qty in
                        onSelect(TradeItem(name: qItem.name, quantity: qty))
                        dismissSheet()
                    }
                }
            }
        }
    }

    private func filterChip(category: ItemCategory?, label: String) -> some View {
        Button(action: { selectedCategory = category }) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(
                    selectedCategory == category ? .white : ApocalypseTheme.textPrimary
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        selectedCategory == category
                        ? ApocalypseTheme.primary
                        : ApocalypseTheme.cardBackground
                    )
                )
        }
    }

    private func itemIcon(name: String) -> some View {
        let def      = inventory.itemDefinitions.first(where: { $0.name == name })
        let iconName = def?.category.iconName ?? "cube.fill"
        let color    = colorFromString(def?.category.color ?? "gray")

        return ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundColor(color)
        }
    }
}

// MARK: - 数量选择页

private struct QuantityPickerView: View {

    let itemName: String
    let maxQty: Int
    let isInventoryBound: Bool
    let onConfirm: (Int) -> Void

    @State private var quantity = 1
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // 物品信息
            VStack(spacing: 8) {
                Text(itemName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if isInventoryBound {
                    Text("背包库存：\(maxQty)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 数量控制
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    Button(action: { if quantity > 1 { quantity -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(
                                quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary
                            )
                    }
                    .disabled(quantity <= 1)

                    Text("\(quantity)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(minWidth: 60)

                    Button(action: { if quantity < max(1, maxQty) { quantity += 1 } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(
                                quantity < maxQty ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary
                            )
                    }
                    .disabled(quantity >= maxQty)
                }

            }
            .padding(20)
            .background(ApocalypseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // 确认按钮
            Button(action: {
                onConfirm(quantity)
                dismiss()
            }) {
                Text("确认选择")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle("选择数量")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    CreateTradeOfferView()
}
