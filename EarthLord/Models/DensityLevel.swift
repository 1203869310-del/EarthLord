//
//  DensityLevel.swift
//  EarthLord
//
//  玩家密度等级 - 根据附近玩家数量决定POI显示数量
//

import Foundation

// MARK: - 玩家密度等级

/// 玩家密度等级
/// 根据1公里内的其他在线玩家数量判定
enum DensityLevel: String, CaseIterable {
    case solo = "独行者"      // 0人
    case low = "低密度"       // 1-5人
    case medium = "中密度"    // 6-20人
    case high = "高密度"      // 20人+

    /// 建议显示的POI数量
    var suggestedPOICount: Int {
        switch self {
        case .solo: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return Int.max  // 不限制，显示所有
        }
    }

    /// 密度等级描述
    var description: String {
        switch self {
        case .solo:
            return "附近没有其他幸存者"
        case .low:
            return "附近有少量幸存者"
        case .medium:
            return "附近有一些幸存者"
        case .high:
            return "附近有很多幸存者"
        }
    }

    /// 根据玩家数量获取密度等级
    /// - Parameter playerCount: 附近玩家数量（不含自己）
    /// - Returns: 对应的密度等级
    static func from(playerCount: Int) -> DensityLevel {
        switch playerCount {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - 玩家位置模型

/// 玩家位置数据（用于数据库查询结果）
struct PlayerLocation: Codable {
    let id: String?
    let userId: String
    let latitude: Double
    let longitude: Double
    let lastUpdatedAt: String?
    let isOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case lastUpdatedAt = "last_updated_at"
        case isOnline = "is_online"
    }
}
