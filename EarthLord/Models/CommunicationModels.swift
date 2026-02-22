//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//

import Foundation
import SwiftUI

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

// MARK: - 频道类型

enum ChannelType: String, Codable, CaseIterable {
    case official  = "official"
    case public_   = "public"   // public 是关键字
    case walkie    = "walkie"
    case camp      = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official:  return "官方频道"
        case .public_:   return "公共频道"
        case .walkie:    return "对讲频道"
        case .camp:      return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official:  return "megaphone"
        case .public_:   return "dot.radiowaves.left.and.right"
        case .walkie:    return "antenna.radiowaves.left.and.right"
        case .camp:      return "tower.broadcast"
        case .satellite: return "satellite"
        }
    }

    var description: String {
        switch self {
        case .official:  return "官方发布的公告与信息频道"
        case .public_:   return "所有玩家可见的开放频道"
        case .walkie:    return "对讲机频段，短距离通讯"
        case .camp:      return "营地内部通讯频道"
        case .satellite: return "卫星通讯，覆盖全球"
        }
    }

    var rangeText: String {
        switch self {
        case .official:  return "全球"
        case .public_:   return "全球"
        case .walkie:    return "5 km"
        case .camp:      return "50 km"
        case .satellite: return "全球"
        }
    }
}

// MARK: - 频道

struct CommunicationChannel: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID?    // nil for official channel
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    var isActive: Bool
    var memberCount: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId   = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive    = "is_active"
        case memberCount = "member_count"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }

    // Hashable：仅基于 id，避免 Date 不可哈希问题
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CommunicationChannel, rhs: CommunicationChannel) -> Bool { lhs.id == rhs.id }
}

// MARK: - 订阅

struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    var isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case channelId = "channel_id"
        case isMuted   = "is_muted"
        case joinedAt  = "joined_at"
    }
}

// MARK: - 组合（频道 + 订阅）

struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription
    var id: UUID { channel.id }
}

// MARK: - 位置点（PostGIS POINT 解析）

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else { return nil }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 消息分类（官方频道专用）

enum MessageCategory: String, Codable, CaseIterable {
    case survival = "survival"
    case news     = "news"
    case mission  = "mission"
    case alert    = "alert"

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news:     return "游戏资讯"
        case .mission:  return "任务发布"
        case .alert:    return "紧急广播"
        }
    }

    var color: Color {
        switch self {
        case .survival: return .green
        case .news:     return .blue
        case .mission:  return .orange
        case .alert:    return .red
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "leaf.fill"
        case .news:     return "newspaper.fill"
        case .mission:  return "target"
        case .alert:    return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - 消息元数据

struct MessageMetadata: Codable {
    let deviceType: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
    }
}

// MARK: - 频道消息

struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId       = "message_id"
        case channelId       = "channel_id"
        case senderId        = "sender_id"
        case senderCallsign  = "sender_callsign"
        case content
        case senderLocation  = "sender_location"
        case metadata
        case createdAt       = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messageId       = try c.decode(UUID.self, forKey: .messageId)
        channelId       = try c.decode(UUID.self, forKey: .channelId)
        senderId        = try c.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign  = try c.decodeIfPresent(String.self, forKey: .senderCallsign)
        content         = try c.decode(String.self, forKey: .content)
        metadata        = try c.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // PostGIS POINT 字符串容错解析
        if let wkt = try? c.decode(String.self, forKey: .senderLocation) {
            senderLocation = LocationPoint.fromPostGIS(wkt)
        } else {
            senderLocation = try c.decodeIfPresent(LocationPoint.self, forKey: .senderLocation)
        }

        // 多格式日期解析
        if let s = try? c.decode(String.self, forKey: .createdAt) {
            createdAt = ChannelMessage.parseDate(s) ?? Date()
        } else {
            createdAt = try c.decode(Date.self, forKey: .createdAt)
        }
    }

    private static func parseDate(_ s: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for fmt in formats {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let date = f.date(from: s) { return date }
        }
        return nil
    }

    var timeAgo: String {
        let i = Date().timeIntervalSince(createdAt)
        if i < 60    { return "刚刚" }
        if i < 3600  { return "\(Int(i/60))分钟前" }
        if i < 86400 { return "\(Int(i/3600))小时前" }
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"
        return f.string(from: createdAt)
    }

    var deviceType: String? { metadata?.deviceType }

    /// 发送者设备类型（从 metadata 解析，向后兼容老消息）
    var senderDeviceType: DeviceType? {
        guard let raw = metadata?.deviceType else { return nil }
        return DeviceType(rawValue: raw)
    }

    /// 消息分类（官方频道专用）
    var category: MessageCategory? {
        guard let raw = metadata?.category else { return nil }
        return MessageCategory(rawValue: raw)
    }
}
