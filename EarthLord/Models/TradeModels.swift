//
//  TradeModels.swift
//  EarthLord
//
//  交易系统数据模型
//

import Foundation

// MARK: - 交易物品

/// 单笔交易中的物品条目（name 与 InventoryManager 中文名称一致）
struct TradeItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let quantity: Int
}

// MARK: - 订单状态

enum TradeStatus: String, Codable {
    case active    = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    case expired   = "expired"   // 仅客户端逻辑，不写回 DB

    var displayName: String {
        switch self {
        case .active:    return "挂单中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired:   return "已过期"
        }
    }
}

// MARK: - 挂单（对应 trade_offers 表）

struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID
    let ownerUsername: String
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    var status: TradeStatus
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    var completedAt: Date?
    var completedByUserId: UUID?
    var completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId              = "owner_id"
        case ownerUsername        = "owner_username"
        case offeringItems        = "offering_items"
        case requestingItems      = "requesting_items"
        case status
        case message
        case createdAt            = "created_at"
        case expiresAt            = "expires_at"
        case completedAt          = "completed_at"
        case completedByUserId    = "completed_by_user_id"
        case completedByUsername  = "completed_by_username"
    }

    /// 客户端判断是否已过期
    var isExpired: Bool { expiresAt <= Date() }
}

// MARK: - 交易历史嵌套结构

/// trade_history.items_exchanged JSONB 字段解码
struct ItemsExchanged: Codable {
    let offered: [TradeItem]    // 卖家提供 → 买家获得
    let requested: [TradeItem]  // 买家支付 → 卖家领取（通过 claimSellerItems）
}

// MARK: - 交易历史（对应 trade_history 表）

struct TradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID
    let sellerId: UUID
    let sellerUsername: String
    let buyerId: UUID
    let buyerUsername: String
    let itemsExchanged: ItemsExchanged
    let completedAt: Date
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?
    var sellerClaimed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case offerId         = "offer_id"
        case sellerId        = "seller_id"
        case sellerUsername  = "seller_username"
        case buyerId         = "buyer_id"
        case buyerUsername   = "buyer_username"
        case itemsExchanged  = "items_exchanged"
        case completedAt     = "completed_at"
        case sellerRating    = "seller_rating"
        case buyerRating     = "buyer_rating"
        case sellerComment   = "seller_comment"
        case buyerComment    = "buyer_comment"
        case sellerClaimed   = "seller_claimed"
    }
}

// MARK: - RPC 返回值

/// accept_trade_offer RPC 函数的返回值
struct AcceptTradeResponse: Decodable {
    let success: Bool
    let error: String?
    let historyId: String?
    let offeringItems: [TradeItem]?
    let requestingItems: [TradeItem]?
    let sellerId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case historyId       = "history_id"
        case offeringItems   = "offering_items"
        case requestingItems = "requesting_items"
        case sellerId        = "seller_id"
    }
}

// MARK: - 交易错误

enum TradeError: Error, LocalizedError {
    case notAuthenticated
    case insufficientItems([String: Int])   // 物品不足，附带每项缺少量
    case offerUnavailable                   // 订单已被抢占或过期
    case offerNotFound                      // 本地找不到订单
    case notOfferOwner                      // 不是订单所有者
    case alreadyClaimed                     // 卖家物品已领取
    case invalidRating                      // 评分超出范围
    case rpcFailed(String)                  // RPC 返回 success=false

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "请先登录"
        case .insufficientItems(let items):
            let desc = items.map { "\($0.key): 还需\($0.value)" }.joined(separator: "，")
            return "物品不足：\(desc)"
        case .offerUnavailable:
            return "订单已被其他玩家接受或已过期"
        case .offerNotFound:
            return "找不到该订单"
        case .notOfferOwner:
            return "只能操作自己的订单"
        case .alreadyClaimed:
            return "物品已领取"
        case .invalidRating:
            return "评分须在 1 到 5 之间"
        case .rpcFailed(let msg):
            return "交易失败：\(msg)"
        }
    }
}
