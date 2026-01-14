//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器 - 管理玩家物品
//

import Foundation
import Combine

// MARK: - 背包管理器

@MainActor
class InventoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = InventoryManager()

    // MARK: - Published Properties

    /// 背包中的所有物品
    @Published var items: [BackpackItem] = []

    /// 背包最大容量
    let maxCapacity: Double = 100.0

    /// 物品定义列表（用于奖励生成）
    @Published var itemDefinitions: [ItemDefinition] = []

    // MARK: - Item Definition

    /// 物品定义（包含名称、分类、稀有度）
    struct ItemDefinition {
        let name: String
        let category: ItemCategory
        let rarity: Rarity
        let weight: Double
        let volume: Double
    }

    // MARK: - Computed Properties

    /// 当前使用容量
    var usedCapacity: Double {
        items.reduce(0) { $0 + ($1.volume * Double($1.quantity)) }
    }

    /// 容量百分比
    var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    // MARK: - Initialization

    private init() {
        // 加载初始物品（从假数据）
        items = MockExplorationData.backpackItems
    }

    // MARK: - Public Methods

    /// 添加物品到背包
    /// - Parameters:
    ///   - name: 物品名称
    ///   - category: 物品分类
    ///   - quantity: 数量
    ///   - rarity: 稀有度
    func addItem(
        name: String,
        category: ItemCategory,
        quantity: Int,
        rarity: Rarity
    ) {
        // 检查是否已有相同物品
        if let index = items.firstIndex(where: { $0.name == name }) {
            // 增加数量
            items[index].quantity += quantity
            print("📦 [背包] 增加物品: \(name) x\(quantity) (总计: \(items[index].quantity))")
        } else {
            // 从物品定义中查找重量和体积
            let definition = itemDefinitions.first(where: { $0.name == name })
            let weight = definition?.weight ?? 0.5
            let volume = definition?.volume ?? 0.5

            // 添加新物品
            let newItem = BackpackItem(
                name: name,
                category: category,
                quantity: quantity,
                weight: weight,
                volume: volume,
                rarity: rarity,
                quality: nil
            )
            items.append(newItem)
            print("📦 [背包] 添加新物品: \(name) x\(quantity)")
        }

        TerritoryLogger.shared.log("获得物品: \(name) x\(quantity)", type: .success)
    }

    /// 移除物品
    /// - Parameters:
    ///   - name: 物品名称
    ///   - quantity: 数量
    func removeItem(name: String, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.name == name }) else {
            print("⚠️ [背包] 物品不存在: \(name)")
            return
        }

        if items[index].quantity > quantity {
            // 减少数量
            items[index].quantity -= quantity
            print("📦 [背包] 减少物品: \(name) x\(quantity) (剩余: \(items[index].quantity))")
        } else {
            // 移除物品
            items.remove(at: index)
            print("📦 [背包] 移除物品: \(name)")
        }
    }

    /// 获取物品数量
    /// - Parameter name: 物品名称
    /// - Returns: 数量
    func getItemQuantity(name: String) -> Int {
        items.first(where: { $0.name == name })?.quantity ?? 0
    }

    /// 清空背包
    func clearAll() {
        items.removeAll()
        print("🗑️ [背包] 清空背包")
    }

    /// 加载物品定义（从数据源）
    func loadItemDefinitions() async {
        // 模拟从服务器或本地数据库加载物品定义
        // 实际项目中可以从 Firebase/CoreData 等加载

        itemDefinitions = [
            // 普通物品（common）
            ItemDefinition(name: "矿泉水", category: .water, rarity: .common, weight: 0.5, volume: 0.5),
            ItemDefinition(name: "面包", category: .food, rarity: .common, weight: 0.3, volume: 0.3),
            ItemDefinition(name: "绷带", category: .medical, rarity: .common, weight: 0.05, volume: 0.05),
            ItemDefinition(name: "木材", category: .material, rarity: .common, weight: 2.0, volume: 3.0),
            ItemDefinition(name: "绳子", category: .tool, rarity: .common, weight: 0.8, volume: 0.5),

            // 稀有物品（rare）
            ItemDefinition(name: "罐头食品", category: .food, rarity: .rare, weight: 0.3, volume: 0.2),
            ItemDefinition(name: "能量棒", category: .food, rarity: .rare, weight: 0.2, volume: 0.1),
            ItemDefinition(name: "废金属", category: .material, rarity: .rare, weight: 1.5, volume: 1.0),
            ItemDefinition(name: "手电筒", category: .tool, rarity: .rare, weight: 0.4, volume: 0.3),

            // 史诗物品（epic）
            ItemDefinition(name: "药品", category: .medical, rarity: .epic, weight: 0.1, volume: 0.08),
            ItemDefinition(name: "高级医疗包", category: .medical, rarity: .epic, weight: 0.5, volume: 0.4),
            ItemDefinition(name: "钢材", category: .material, rarity: .epic, weight: 5.0, volume: 2.0)
        ]

        print("📦 [背包] 已加载 \(itemDefinitions.count) 种物品定义")
        TerritoryLogger.shared.log("物品定义加载完成", type: .info)
    }
}
