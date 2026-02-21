//
//  TradeManager.swift
//  EarthLord
//
//  交易系统管理器 - 处理挂单创建、接受、取消和历史查询
//

import Foundation
import Supabase

// MARK: - 交易管理器

@MainActor
final class TradeManager: ObservableObject {

    // MARK: - 单例

    static let shared = TradeManager()

    // MARK: - 发布属性

    @Published var myOffers: [TradeOffer] = []
    @Published var availableOffers: [TradeOffer] = []
    @Published var tradeHistory: [TradeHistory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期字符串: \(string)"
            )
        }
        return d
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 创建挂单

    /// 创建新的交易挂单
    /// - Parameters:
    ///   - offering: 卖家提供的物品列表
    ///   - requesting: 卖家请求换取的物品列表
    ///   - expiresInHours: 挂单有效时长（小时）
    ///   - message: 可选备注
    func createTradeOffer(
        offering: [TradeItem],
        requesting: [TradeItem],
        expiresInHours: Double = 24,
        message: String? = nil
    ) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TradeError.notAuthenticated
        }

        // 验证库存是否充足
        var missing: [String: Int] = [:]
        for item in offering {
            let owned = InventoryManager.shared.getItemQuantity(name: item.name)
            if owned < item.quantity {
                missing[item.name] = item.quantity - owned
            }
        }
        if !missing.isEmpty {
            throw TradeError.insufficientItems(missing)
        }

        // 预扣库存（内存锁定）
        for item in offering {
            InventoryManager.shared.removeItem(name: item.name, quantity: item.quantity)
        }

        // 构建插入数据
        let now = Date()
        let expiresAt = now.addingTimeInterval(expiresInHours * 3600)
        let offerId = UUID()

        let insertData: [String: AnyJSON] = [
            "id":               .string(offerId.uuidString),
            "owner_id":         .string(userId.uuidString),
            "owner_username":   .string(userId.uuidString), // 使用 userId 作为默认用户名
            "offering_items":   try encodeItemsToAnyJSON(offering),
            "requesting_items": try encodeItemsToAnyJSON(requesting),
            "status":           .string("active"),
            "message":          message.map { .string($0) } ?? .null,
            "created_at":       .string(now.ISO8601Format()),
            "expires_at":       .string(expiresAt.ISO8601Format())
        ]

        do {
            try await supabase.from("trade_offers").insert(insertData).execute()
        } catch {
            // 回滚库存
            for item in offering {
                let (category, rarity) = lookupItemDefinition(name: item.name)
                InventoryManager.shared.addItem(
                    name: item.name, category: category,
                    quantity: item.quantity, rarity: rarity
                )
            }
            print("[TradeManager] ❌ 创建挂单失败: \(error)")
            throw error
        }

        // 追加到本地缓存
        let newOffer = TradeOffer(
            id: offerId,
            ownerId: userId,
            ownerUsername: userId.uuidString,
            offeringItems: offering,
            requestingItems: requesting,
            status: .active,
            message: message,
            createdAt: now,
            expiresAt: expiresAt,
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )
        myOffers.insert(newOffer, at: 0)
        print("[TradeManager] ✅ 创建挂单成功: \(offerId)")
    }

    // MARK: - 接受挂单

    /// 接受一个活跃挂单（通过 RPC 原子执行）
    /// - Parameter offerId: 挂单 ID
    func acceptTradeOffer(offerId: UUID) async throws {
        guard AuthManager.shared.currentUserId != nil else {
            throw TradeError.notAuthenticated
        }

        // 找到本地 offer 并验证买家库存
        guard let offer = availableOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        var missing: [String: Int] = [:]
        for item in offer.requestingItems {
            let owned = InventoryManager.shared.getItemQuantity(name: item.name)
            if owned < item.quantity {
                missing[item.name] = item.quantity - owned
            }
        }
        if !missing.isEmpty {
            throw TradeError.insufficientItems(missing)
        }

        // 预扣买家库存
        for item in offer.requestingItems {
            InventoryManager.shared.removeItem(name: item.name, quantity: item.quantity)
        }

        // 调用 RPC
        let params: [String: AnyJSON] = ["offer_id": .string(offerId.uuidString)]
        let responseData: Data
        do {
            let result = try await supabase.rpc("accept_trade_offer", params: params).execute()
            responseData = result.data
        } catch {
            // 回滚买家库存
            for item in offer.requestingItems {
                let (category, rarity) = lookupItemDefinition(name: item.name)
                InventoryManager.shared.addItem(
                    name: item.name, category: category,
                    quantity: item.quantity, rarity: rarity
                )
            }
            print("[TradeManager] ❌ RPC 调用失败: \(error)")
            throw error
        }

        // 解码 RPC 返回值
        let response: AcceptTradeResponse
        do {
            response = try decoder.decode(AcceptTradeResponse.self, from: responseData)
        } catch {
            // 回滚买家库存
            for item in offer.requestingItems {
                let (category, rarity) = lookupItemDefinition(name: item.name)
                InventoryManager.shared.addItem(
                    name: item.name, category: category,
                    quantity: item.quantity, rarity: rarity
                )
            }
            throw error
        }

        guard response.success else {
            // 回滚买家库存
            for item in offer.requestingItems {
                let (category, rarity) = lookupItemDefinition(name: item.name)
                InventoryManager.shared.addItem(
                    name: item.name, category: category,
                    quantity: item.quantity, rarity: rarity
                )
            }
            throw TradeError.offerUnavailable
        }

        // 买家获得 offeringItems
        if let received = response.offeringItems {
            for item in received {
                let (category, rarity) = lookupItemDefinition(name: item.name)
                InventoryManager.shared.addItem(
                    name: item.name, category: category,
                    quantity: item.quantity, rarity: rarity
                )
            }
        }

        // 更新本地缓存
        availableOffers.removeAll { $0.id == offerId }
        if let idx = myOffers.firstIndex(where: { $0.id == offerId }) {
            myOffers[idx].status = .completed
        }

        print("[TradeManager] ✅ 接受挂单成功: \(offerId)")
    }

    // MARK: - 取消挂单

    /// 取消自己的活跃挂单并退还物品
    /// - Parameter offerId: 挂单 ID
    func cancelTradeOffer(offerId: UUID) async throws {
        guard AuthManager.shared.currentUserId != nil else {
            throw TradeError.notAuthenticated
        }

        guard let offer = myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }
        guard offer.status == .active else {
            throw TradeError.offerUnavailable
        }

        try await supabase.from("trade_offers")
            .update(["status": "cancelled"])
            .eq("id", value: offerId.uuidString)
            .execute()

        // 退还 offeringItems
        for item in offer.offeringItems {
            let (category, rarity) = lookupItemDefinition(name: item.name)
            InventoryManager.shared.addItem(
                name: item.name, category: category,
                quantity: item.quantity, rarity: rarity
            )
        }

        // 更新本地缓存
        if let idx = myOffers.firstIndex(where: { $0.id == offerId }) {
            myOffers[idx].status = .cancelled
        }

        print("[TradeManager] ✅ 取消挂单成功: \(offerId)")
    }

    // MARK: - 加载我的挂单

    /// 从 Supabase 加载当前用户的所有挂单
    func loadMyOffers() async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TradeError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let response = try await supabase.from("trade_offers")
            .select()
            .eq("owner_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        let offers = try decoder.decode([TradeOffer].self, from: response.data)
        myOffers = offers
        print("[TradeManager] ✅ 加载我的挂单: \(offers.count) 条")

        processExpiredOffers()
    }

    // MARK: - 加载可接受的挂单

    /// 从 Supabase 加载其他玩家的活跃挂单
    func loadAvailableOffers() async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TradeError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let isoNow = Date().ISO8601Format()

        let response = try await supabase.from("trade_offers")
            .select()
            .eq("status", value: "active")
            .gt("expires_at", value: isoNow)
            .neq("owner_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        availableOffers = try decoder.decode([TradeOffer].self, from: response.data)
        print("[TradeManager] ✅ 加载可用挂单: \(availableOffers.count) 条")
    }

    // MARK: - 加载交易历史

    /// 从 Supabase 加载当前用户参与的交易历史（买家 + 卖家）
    func loadTradeHistory() async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TradeError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let response = try await supabase.from("trade_history")
            .select()
            .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
            .order("completed_at", ascending: false)
            .execute()

        tradeHistory = try decoder.decode([TradeHistory].self, from: response.data)
        print("[TradeManager] ✅ 加载交易历史: \(tradeHistory.count) 条")
    }

    // MARK: - 评价交易

    /// 对一笔已完成交易进行评价
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分（1~5）
    ///   - comment: 评价备注（可选）
    func rateTrade(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TradeError.notAuthenticated
        }
        guard (1...5).contains(rating) else {
            throw TradeError.invalidRating
        }
        guard let record = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.offerNotFound
        }

        if record.sellerId == userId {
            // 卖家评价
            var updateData: [String: AnyJSON] = ["seller_rating": .integer(rating)]
            if let comment { updateData["seller_comment"] = .string(comment) }
            try await supabase.from("trade_history")
                .update(updateData)
                .eq("id", value: historyId.uuidString)
                .execute()
        } else if record.buyerId == userId {
            // 买家评价
            var updateData: [String: AnyJSON] = ["buyer_rating": .integer(rating)]
            if let comment { updateData["buyer_comment"] = .string(comment) }
            try await supabase.from("trade_history")
                .update(updateData)
                .eq("id", value: historyId.uuidString)
                .execute()
        } else {
            throw TradeError.notOfferOwner
        }

        // 更新本地缓存
        if let idx = tradeHistory.firstIndex(where: { $0.id == historyId }) {
            if record.sellerId == userId {
                tradeHistory[idx].sellerRating = rating
                tradeHistory[idx].sellerComment = comment
            } else {
                tradeHistory[idx].buyerRating = rating
                tradeHistory[idx].buyerComment = comment
            }
        }

        print("[TradeManager] ✅ 评价完成: \(historyId), 评分: \(rating)")
    }

    // MARK: - 领取卖家所得物品

    /// 卖家领取交易中买家支付的物品（跨会话持久化）
    /// - Parameter historyId: 交易历史 ID
    func claimSellerItems(historyId: UUID) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TradeError.notAuthenticated
        }

        guard let record = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.offerNotFound
        }
        guard record.sellerId == userId else {
            throw TradeError.notOfferOwner
        }
        guard !record.sellerClaimed else {
            throw TradeError.alreadyClaimed
        }

        try await supabase.from("trade_history")
            .update(["seller_claimed": true])
            .eq("id", value: historyId.uuidString)
            .execute()

        // 将买家支付的物品（requested）发给卖家
        for item in record.itemsExchanged.requested {
            let (category, rarity) = lookupItemDefinition(name: item.name)
            InventoryManager.shared.addItem(
                name: item.name, category: category,
                quantity: item.quantity, rarity: rarity
            )
        }

        // 更新本地缓存
        if let idx = tradeHistory.firstIndex(where: { $0.id == historyId }) {
            tradeHistory[idx].sellerClaimed = true
        }

        print("[TradeManager] ✅ 卖家领取物品完成: \(historyId)")
    }

    // MARK: - 处理过期订单（私有）

    /// 处理已过期的活跃订单：退还物品并更新状态；同时重新锁定仍活跃订单的物品（应对重启后内存重置）
    private func processExpiredOffers() {
        for i in myOffers.indices {
            let offer = myOffers[i]
            guard offer.status == .active else { continue }

            if offer.isExpired {
                // 退还过期订单物品
                for item in offer.offeringItems {
                    let (category, rarity) = lookupItemDefinition(name: item.name)
                    InventoryManager.shared.addItem(
                        name: item.name, category: category,
                        quantity: item.quantity, rarity: rarity
                    )
                }
                myOffers[i].status = .expired
                print("[TradeManager] ⏱ 订单过期，退还物品: \(offer.id)")
            } else {
                // 重新从内存中锁定活跃订单的物品（重启后 MockData 可能恢复）
                for item in offer.offeringItems {
                    let owned = InventoryManager.shared.getItemQuantity(name: item.name)
                    if owned >= item.quantity {
                        InventoryManager.shared.removeItem(name: item.name, quantity: item.quantity)
                    }
                }
            }
        }
    }
}

// MARK: - 私有辅助方法

private extension TradeManager {

    /// 将 [TradeItem] 编码为 AnyJSON 数组（用于 Supabase insert）
    func encodeItemsToAnyJSON(_ items: [TradeItem]) throws -> AnyJSON {
        let data = try JSONEncoder().encode(items)
        let raw = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        return .array(raw.map { dict in
            .object(dict.mapValues { v in
                if let s = v as? String { return AnyJSON.string(s) }
                if let i = v as? Int    { return AnyJSON.integer(i) }
                return AnyJSON.string("\(v)")
            })
        })
    }

    /// 根据物品名称从 itemDefinitions 查询分类和稀有度
    func lookupItemDefinition(name: String) -> (ItemCategory, Rarity) {
        if let def = InventoryManager.shared.itemDefinitions.first(where: { $0.name == name }) {
            return (def.category, def.rarity)
        }
        return (.material, .common)
    }
}
