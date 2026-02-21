//
//  BuildingModels.swift
//  EarthLord
//
//  建造系统数据模型
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - 建筑分类

enum BuildingCategory: String, Codable, CaseIterable {
    case survival   = "survival"    // 生存类
    case storage    = "storage"     // 存储类
    case production = "production"  // 生产类
    case energy     = "energy"      // 能源类

    var displayName: String {
        switch self {
        case .survival:   return "生存"
        case .storage:    return "存储"
        case .production: return "生产"
        case .energy:     return "能源"
        }
    }
}

// MARK: - 建筑状态

enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active       = "active"        // 运行中

    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active:       return "运行中"
        }
    }

    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active:       return .green
        }
    }
}

// MARK: - 建筑错误

enum BuildingError: Error, LocalizedError {
    case insufficientResources([String: Int])   // 资源不足，附带缺少量
    case maxBuildingsReached(Int)               // 超过领地建筑上限
    case templateNotFound                       // 建筑模板不存在
    case invalidStatus                          // 建筑状态不符
    case maxLevelReached                        // 已达最大等级

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let resources):
            let desc = resources.map { "\($0.key): 还需\($0.value)" }.joined(separator: "，")
            return "资源不足：\(desc)"
        case .maxBuildingsReached(let max):
            return "该领地此建筑数量已达上限（\(max)）"
        case .templateNotFound:
            return "建筑模板不存在"
        case .invalidStatus:
            return "建筑当前状态不允许此操作"
        case .maxLevelReached:
            return "建筑已达到最大等级"
        }
    }
}

// MARK: - 建筑模板（从 JSON 加载）

struct BuildingTemplate: Codable, Identifiable {
    let id: UUID
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId       = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds  = "build_time_seconds"
        case maxPerTerritory   = "max_per_territory"
        case maxLevel          = "max_level"
    }
}

// MARK: - 玩家建筑（Supabase 表记录）

struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId         = "user_id"
        case territoryId    = "territory_id"
        case templateId     = "template_id"
        case buildingName   = "building_name"
        case status
        case level
        case locationLat    = "location_lat"
        case locationLon    = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt      = "created_at"
    }
}

// MARK: - PlayerBuilding 计算属性

extension PlayerBuilding {
    /// 位置坐标（GCJ-02，直接使用无需转换）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 建造进度 0.0 ~ 1.0
    var buildProgress: Double {
        guard status == .constructing, let completedAt = buildCompletedAt else { return 0 }
        let total = completedAt.timeIntervalSince(buildStartedAt)
        guard total > 0 else { return 1 }
        return min(1.0, max(0, Date().timeIntervalSince(buildStartedAt) / total))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        guard status == .constructing, let completedAt = buildCompletedAt else { return "" }
        let r = completedAt.timeIntervalSince(Date())
        guard r > 0 else { return "即将完成" }
        let h = Int(r) / 3600; let m = (Int(r) % 3600) / 60; let s = Int(r) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

// MARK: - 建筑地图标注

/// 建筑地图标注（用于主地图和领地地图显示建筑位置）
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    dynamic var coordinate: CLLocationCoordinate2D

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.template = template
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }

    var title: String? { building.buildingName }
    var subtitle: String? { building.status.displayName }
}
