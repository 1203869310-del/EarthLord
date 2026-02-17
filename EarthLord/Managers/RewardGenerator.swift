//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器 - 根据等级生成随机奖励（支持 AI 生成 + 本地降级）
//

import Foundation

// MARK: - 奖励生成器

struct RewardGenerator {

    // MARK: - AI 生成入口（带降级）

    /// AI 生成 POI 奖励（带本地降级）
    /// - Parameters:
    ///   - poi: 兴趣点
    ///   - itemCount: 物品数量
    /// - Returns: 奖励物品列表
    @MainActor
    static func generatePOIRewardsWithAI(poi: POI, itemCount: Int = 3) async -> [RewardItem] {
        do {
            // 尝试 AI 生成
            let aiItems = try await AIItemService.shared.generateItems(for: poi, itemCount: itemCount)
            print("✅ [奖励] AI 生成成功: \(aiItems.count) 个物品")
            return aiItems
        } catch {
            // AI 生成失败，使用本地降级
            print("⚠️ [奖励] AI 生成失败，使用本地降级: \(error.localizedDescription)")
            TerritoryLogger.shared.log("AI降级: \(error.localizedDescription)", type: .warning)
            return generateLocalRewards(poi: poi, itemCount: itemCount)
        }
    }

    /// 本地降级方案
    /// - Parameters:
    ///   - poi: 兴趣点
    ///   - itemCount: 物品数量
    /// - Returns: 本地生成的奖励物品列表
    @MainActor
    static func generateLocalRewards(poi: POI, itemCount: Int) -> [RewardItem] {
        var rewards: [RewardItem] = []

        let itemDefinitions = InventoryManager.shared.itemDefinitions
        guard !itemDefinitions.isEmpty else {
            print("⚠️ [本地奖励] 物品定义为空")
            return rewards
        }

        // 获取 POI 配置
        let (_, preferredCategories, _) = poiRewardConfig(for: poi.type)

        // 获取危险等级的稀有度权重
        let weights = poi.dangerLevel.rarityWeights

        // 优先从偏好类别中选择物品
        let preferredItems = itemDefinitions.filter { preferredCategories.contains($0.category) }
        let otherItems = itemDefinitions.filter { !preferredCategories.contains($0.category) }

        for i in 0..<itemCount {
            let usePreferred = i < itemCount / 2 + 1 && !preferredItems.isEmpty
            let poolToUse = usePreferred ? preferredItems : (preferredItems + otherItems)

            // 根据危险等级的概率决定稀有度
            let rarity = randomRarityFromWeights(weights)

            // 从对应稀有度的物品池中随机选择
            let itemsOfRarity = poolToUse.filter { $0.rarity == rarity }
            let fallbackItems = poolToUse.filter { $0.rarity == .common }

            if let randomItem = itemsOfRarity.randomElement() ?? fallbackItems.randomElement() {
                let quantity = Int.random(in: 1...3)
                let reward = RewardItem(
                    name: randomItem.name,
                    quantity: quantity,
                    iconName: randomItem.category.iconName,
                    category: randomItem.category,
                    rarity: randomItem.rarity
                )
                rewards.append(reward)
            }
        }

        return rewards
    }

    /// 根据危险等级权重随机选择稀有度
    private static func randomRarityFromWeights(_ weights: RarityWeights) -> Rarity {
        let totalWeight = weights.common + weights.uncommon + weights.rare + weights.epic + weights.legendary
        let randomValue = Double.random(in: 0..<totalWeight)

        var cumulative = 0.0
        cumulative += weights.common
        if randomValue < cumulative { return .common }

        cumulative += weights.uncommon
        if randomValue < cumulative { return .uncommon }

        cumulative += weights.rare
        if randomValue < cumulative { return .rare }

        cumulative += weights.epic
        if randomValue < cumulative { return .epic }

        return .legendary
    }

    // MARK: - 原有 Public Methods

    /// 根据 POI 类型生成奖励物品（本地生成，保持兼容）
    /// - Parameter poiType: POI 类型
    /// - Returns: 奖励物品列表
    @MainActor
    static func generatePOIRewards(poiType: POIType) -> [RewardItem] {
        var rewards: [RewardItem] = []

        // 从 InventoryManager 获取物品定义
        let itemDefinitions = InventoryManager.shared.itemDefinitions

        guard !itemDefinitions.isEmpty else {
            print("⚠️ [POI奖励] 物品定义为空，无法生成奖励")
            return rewards
        }

        // 根据 POI 类型确定物品数量和类别偏好
        let (itemCount, preferredCategories, weights) = poiRewardConfig(for: poiType)

        // 优先从偏好类别中选择物品
        let preferredItems = itemDefinitions.filter { preferredCategories.contains($0.category) }
        let otherItems = itemDefinitions.filter { !preferredCategories.contains($0.category) }

        for i in 0..<itemCount {
            // 前面的物品更倾向于从偏好类别中选择
            let usePreferred = i < itemCount / 2 + 1 && !preferredItems.isEmpty

            let poolToUse = usePreferred ? preferredItems : (preferredItems + otherItems)

            // 根据概率决定稀有度
            let rarity = randomRarity(
                commonWeight: weights.common,
                rareWeight: weights.rare,
                epicWeight: weights.epic
            )

            // 从对应稀有度的物品池中随机选择
            let itemsOfRarity = poolToUse.filter { $0.rarity == rarity }
            let fallbackItems = poolToUse.filter { $0.rarity == .common }

            if let randomItem = itemsOfRarity.randomElement() ?? fallbackItems.randomElement() {
                let quantity = Int.random(in: 1...3)
                let reward = RewardItem(
                    name: randomItem.name,
                    quantity: quantity,
                    iconName: randomItem.category.iconName,
                    category: randomItem.category,
                    rarity: randomItem.rarity
                )
                rewards.append(reward)
            }
        }

        return rewards
    }

    /// 根据 POI 类型获取奖励配置
    private static func poiRewardConfig(for poiType: POIType) -> (itemCount: Int, categories: [ItemCategory], weights: (common: Double, rare: Double, epic: Double)) {
        switch poiType {
        case .hospital:
            return (3, [.medical], (common: 0.5, rare: 0.35, epic: 0.15))
        case .pharmacy:
            return (2, [.medical], (common: 0.6, rare: 0.3, epic: 0.1))
        case .supermarket:
            return (3, [.food, .water], (common: 0.7, rare: 0.25, epic: 0.05))
        case .gasStation:
            return (2, [.material], (common: 0.6, rare: 0.3, epic: 0.1))
        case .factory:
            return (3, [.material, .tool], (common: 0.5, rare: 0.35, epic: 0.15))
        }
    }

    /// 根据奖励等级生成奖励物品
    /// - Parameter tier: 奖励等级
    /// - Returns: 奖励物品列表
    @MainActor
    static func generateRewards(tier: RewardTier) -> [RewardItem] {
        var rewards: [RewardItem] = []
        let itemCount = tier.itemCount

        guard itemCount > 0 else {
            return rewards
        }

        // 从 InventoryManager 获取物品定义
        let itemDefinitions = InventoryManager.shared.itemDefinitions

        // 如果物品定义为空，返回空奖励
        guard !itemDefinitions.isEmpty else {
            print("⚠️ [奖励生成] 物品定义为空，无法生成奖励")
            return rewards
        }

        // 获取稀有度权重
        let weights = tier.rarityWeights

        // 随机抽取物品
        for _ in 0..<itemCount {
            // 根据概率决定稀有度
            let rarity = randomRarity(
                commonWeight: weights.common,
                rareWeight: weights.rare,
                epicWeight: weights.epic
            )

            // 从对应稀有度的物品池中随机选择
            let itemsOfRarity = itemDefinitions.filter { $0.rarity == rarity }

            if let randomItem = itemsOfRarity.randomElement() {
                let quantity = Int.random(in: 1...5)
                let reward = RewardItem(
                    name: randomItem.name,
                    quantity: quantity,
                    iconName: randomItem.category.iconName,
                    category: randomItem.category,
                    rarity: randomItem.rarity
                )
                rewards.append(reward)
            }
        }

        return rewards
    }

    // MARK: - Private Methods

    /// 根据权重随机选择稀有度
    /// - Parameters:
    ///   - commonWeight: 普通物品权重
    ///   - rareWeight: 稀有物品权重
    ///   - epicWeight: 史诗物品权重
    /// - Returns: 随机选中的稀有度
    private static func randomRarity(
        commonWeight: Double,
        rareWeight: Double,
        epicWeight: Double
    ) -> Rarity {
        let totalWeight = commonWeight + rareWeight + epicWeight
        let randomValue = Double.random(in: 0..<totalWeight)

        if randomValue < commonWeight {
            return .common
        } else if randomValue < commonWeight + rareWeight {
            return .rare
        } else {
            return .epic
        }
    }
}
