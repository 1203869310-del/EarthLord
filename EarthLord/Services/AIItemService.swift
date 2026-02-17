//
//  AIItemService.swift
//  EarthLord
//
//  AI 物品生成服务 - 调用 Supabase Edge Function
//

import Foundation
import Supabase

// MARK: - AI 物品服务

/// AI 物品生成服务
/// 通过 Supabase Edge Function 调用阿里云百炼 qwen-flash 模型生成物品
@MainActor
class AIItemService {

    // MARK: - Singleton

    static let shared = AIItemService()

    private init() {}

    // MARK: - Constants

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 10.0

    // MARK: - Public Methods

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 兴趣点
    ///   - itemCount: 生成物品数量
    /// - Returns: AI 生成的物品列表
    func generateItems(for poi: POI, itemCount: Int) async throws -> [RewardItem] {
        print("🤖 [AI物品] 开始生成物品 - POI: \(poi.name), 数量: \(itemCount)")
        TerritoryLogger.shared.log("AI生成物品: \(poi.name)", type: .info)

        // 创建请求
        let request = AIItemRequest.from(poi: poi, itemCount: itemCount)

        // 调用 Edge Function
        let response: AIItemResponse = try await withThrowingTaskGroup(of: AIItemResponse.self) { group in
            // 主任务：调用 API
            group.addTask {
                try await self.callEdgeFunction(request: request)
            }

            // 超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.requestTimeout * 1_000_000_000))
                throw AIItemError.timeout
            }

            // 返回第一个完成的任务结果
            guard let result = try await group.next() else {
                throw AIItemError.invalidResponse
            }

            // 取消其他任务
            group.cancelAll()

            return result
        }

        // 处理响应
        guard response.success, let items = response.items else {
            let errorMessage = response.error ?? "未知错误"
            print("❌ [AI物品] 生成失败: \(errorMessage)")
            throw AIItemError.generationFailed(errorMessage)
        }

        // 转换为 RewardItem
        let rewardItems = items.map { item in
            item.toRewardItem(quantity: Int.random(in: 1...3))
        }

        print("✅ [AI物品] 成功生成 \(rewardItems.count) 个物品")
        TerritoryLogger.shared.log("AI生成成功: \(rewardItems.count)件", type: .success)

        return rewardItems
    }

    // MARK: - Private Methods

    /// 调用 Edge Function
    private func callEdgeFunction(request: AIItemRequest) async throws -> AIItemResponse {
        do {
            let response: AIItemResponse = try await SupabaseManager.shared.client.functions
                .invoke(
                    "generate-items",
                    options: .init(body: request)
                )

            return response
        } catch {
            print("❌ [AI物品] Edge Function 调用失败: \(error)")
            throw AIItemError.networkError(error.localizedDescription)
        }
    }
}
