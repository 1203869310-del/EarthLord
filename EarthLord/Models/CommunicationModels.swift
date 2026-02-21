//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//

import Foundation

// MARK: - 设备类型

enum DeviceType: String, Codable, CaseIterable {
    case radio        = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio    = "camp_radio"
    case satellite    = "satellite"

    var displayName: String {
        switch self {
        case .radio:        return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio:    return "营地电台"
        case .satellite:    return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio:        return "radio"
        case .walkieTalkie: return "antenna.radiowaves.left.and.right"
        case .campRadio:    return "tower.broadcast"
        case .satellite:    return "satellite"
        }
    }

    var description: String {
        switch self {
        case .radio:
            return "接收广播信息，了解世界动态"
        case .walkieTalkie:
            return "与附近玩家进行短距离通讯"
        case .campRadio:
            return "营地级电台，覆盖范围更广"
        case .satellite:
            return "卫星通讯，全球范围无限制"
        }
    }

    /// 通讯范围（千米），nil 表示无限制
    var range: Double? {
        switch self {
        case .radio:        return nil   // 只接收
        case .walkieTalkie: return 5.0
        case .campRadio:    return 50.0
        case .satellite:    return nil   // 全球
        }
    }

    var rangeText: String {
        switch self {
        case .radio:        return "仅接收"
        case .walkieTalkie: return "5 km"
        case .campRadio:    return "50 km"
        case .satellite:    return "全球"
        }
    }

    /// 是否支持发送消息
    var canSend: Bool {
        switch self {
        case .radio:        return false
        case .walkieTalkie: return true
        case .campRadio:    return true
        case .satellite:    return true
        }
    }

    /// 解锁需求描述（nil 表示默认解锁）
    var unlockRequirement: String? {
        switch self {
        case .radio:        return nil
        case .walkieTalkie: return nil
        case .campRadio:    return "建造「营地电台」建筑"
        case .satellite:    return "建造「卫星天线」建筑"
        }
    }
}

// MARK: - 通讯设备（Supabase 表记录）

struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case deviceType  = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked  = "is_unlocked"
        case isCurrent   = "is_current"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}

// MARK: - 通讯界面分区

enum CommunicationSection: String, CaseIterable {
    case messages = "messages"
    case channels = "channels"
    case call     = "call"
    case devices  = "devices"

    var displayName: String {
        switch self {
        case .messages: return "消息"
        case .channels: return "频道"
        case .call:     return "通话"
        case .devices:  return "设备"
        }
    }

    var iconName: String {
        switch self {
        case .messages: return "message"
        case .channels: return "antenna.radiowaves.left.and.right"
        case .call:     return "phone"
        case .devices:  return "radio"
        }
    }
}
