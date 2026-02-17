//
//  AIGeneratedItem.swift
//  EarthLord
//
//  AI 生成物品的数据模型
//

import Foundation

// MARK: - AI 物品请求

/// AI 物品生成请求
struct AIItemRequest: Encodable {
    let poiType: String
    let poiName: String
    let dangerLevel: Int
    let itemCount: Int
    let rarityDistribution: [String: Double]

    /// 从 POI 创建请求
    static func from(poi: POI, itemCount: Int) -> AIItemRequest {
        let weights = poi.dangerLevel.rarityWeights
        return AIItemRequest(
            poiType: poi.type.rawValue,
            poiName: poi.name,
            dangerLevel: poi.dangerLevel.rawValue + 1,  // 转为 1-5
            itemCount: itemCount,
            rarityDistribution: weights.toDictionary
        )
    }
}

// MARK: - AI 物品响应

/// AI 物品生成响应
struct AIItemResponse: Decodable {
    let success: Bool
    let items: [AIGeneratedItemData]?
    let error: String?
}

/// AI 生成的物品数据
struct AIGeneratedItemData: Decodable {
    let name: String      // 物品名称（如"老张的最后晚餐"）
    let category: String  // 分类：medical/food/tool/weapon/material/water
    let rarity: String    // 稀有度：common/uncommon/rare/epic/legendary
    let story: String     // 背景故事

    /// 转换为游戏内分类
    var itemCategory: ItemCategory {
        switch category.lowercased() {
        case "medical": return .medical
        case "food": return .food
        case "tool": return .tool
        case "material": return .material
        case "water": return .water
        default: return .material
        }
    }

    /// 转换为游戏内稀有度
    var itemRarity: Rarity {
        Rarity.from(apiString: rarity)
    }

    /// 转换为 RewardItem
    func toRewardItem(quantity: Int = 1) -> RewardItem {
        RewardItem(
            name: name,
            quantity: quantity,
            iconName: itemCategory.iconName,
            category: itemCategory,
            rarity: itemRarity,
            story: story,
            isAIGenerated: true
        )
    }
}

// MARK: - AI 物品错误

/// AI 物品生成错误
enum AIItemError: Error, LocalizedError {
    case networkError(String)
    case generationFailed(String)
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .generationFailed(let message):
            return "生成失败: \(message)"
        case .invalidResponse:
            return "无效响应"
        case .timeout:
            return "请求超时"
        }
    }
}
