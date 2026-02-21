//
//  BuildingManager.swift
//  EarthLord
//
//  建造系统管理器 - 处理建筑的建造、升级和查询
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 建造管理器

@MainActor
final class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 发布属性

    @Published var buildingTemplates: [BuildingTemplate] = []
    @Published var playerBuildings: [PlayerBuilding] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var buildingTimers: [UUID: Task<Void, Never>] = [:]

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

    // MARK: - 加载建筑模板

    /// 从 Bundle 中加载建筑模板 JSON
    func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("[BuildingManager] ❌ 找不到 building_templates.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let templateDecoder = JSONDecoder()
            templateDecoder.keyDecodingStrategy = .convertFromSnakeCase

            let container = try templateDecoder.decode(TemplatesContainer.self, from: data)
            buildingTemplates = container.templates
            print("[BuildingManager] ✅ 成功加载 \(buildingTemplates.count) 个建筑模板")
        } catch {
            print("[BuildingManager] ❌ 解析建筑模板失败: \(error)")
        }
    }

    // MARK: - 检查是否可以建造

    /// 检查指定模板在领地内是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    ///   - playerResources: 玩家当前拥有的资源 [资源名: 数量]
    /// - Returns: (是否可以建造, 失败原因)
    func canBuild(
        template: BuildingTemplate,
        territoryId: String,
        playerResources: [String: Int]
    ) -> (Bool, BuildingError?) {
        // 1. 检查资源是否足够
        var missing: [String: Int] = [:]
        for (resource, required) in template.requiredResources {
            let owned = playerResources[resource] ?? 0
            if owned < required {
                missing[resource] = required - owned
            }
        }
        if !missing.isEmpty {
            return (false, .insufficientResources(missing))
        }

        // 2. 检查领地建筑数量上限
        let count = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count
        if count >= template.maxPerTerritory {
            return (false, .maxBuildingsReached(template.maxPerTerritory))
        }

        return (true, nil)
    }

    // MARK: - 开始建造

    /// 开始建造一个新建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建造位置（可选）
    /// - Returns: 成功时返回新建筑记录，失败时返回错误
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: CLLocationCoordinate2D? = nil
    ) async -> Result<PlayerBuilding, BuildingError> {

        // 1. 查找模板
        guard let template = getTemplate(for: templateId) else {
            return .failure(.templateNotFound)
        }

        // 2. 获取玩家当前背包资源
        var playerResources: [String: Int] = [:]
        for resourceName in template.requiredResources.keys {
            playerResources[resourceName] = InventoryManager.shared.getItemQuantity(name: resourceName)
        }

        // 3. 检查是否可以建造
        let (canBuildResult, buildError) = canBuild(
            template: template,
            territoryId: territoryId,
            playerResources: playerResources
        )
        guard canBuildResult else {
            return .failure(buildError!)
        }

        // 4. 准备建筑数据
        guard let userId = AuthManager.shared.currentUserId else {
            return .failure(.templateNotFound) // 未登录视为模板查找失败兜底
        }

        let now = Date()
        let completedAt = now.addingTimeInterval(Double(template.buildTimeSeconds))
        let buildingId = UUID()

        var insertData: [String: AnyJSON] = [
            "id":               .string(buildingId.uuidString),
            "user_id":          .string(userId.uuidString),
            "territory_id":     .string(territoryId),
            "template_id":      .string(template.templateId),
            "building_name":    .string(template.name),
            "status":           .string(BuildingStatus.constructing.rawValue),
            "level":            .integer(1),
            "build_started_at": .string(now.ISO8601Format()),
            "build_completed_at": .string(completedAt.ISO8601Format())
        ]

        if let location = location {
            insertData["location_lat"] = .double(location.latitude)
            insertData["location_lon"] = .double(location.longitude)
        }

        // 5. 插入 Supabase（先入库，再扣资源，保证原子性）
        do {
            try await supabase.from("player_buildings").insert(insertData).execute()
        } catch {
            errorMessage = "建造失败: \(error.localizedDescription)"
            print("[BuildingManager] ❌ 插入建筑失败: \(error)")
            return .failure(.templateNotFound)
        }

        // 6. 扣除资源
        for (name, quantity) in template.requiredResources {
            InventoryManager.shared.removeItem(name: name, quantity: quantity)
        }

        // 7. 创建本地记录
        let newBuilding = PlayerBuilding(
            id: buildingId,
            userId: userId,
            territoryId: territoryId,
            templateId: template.templateId,
            buildingName: template.name,
            status: .constructing,
            level: 1,
            locationLat: location?.latitude,
            locationLon: location?.longitude,
            buildStartedAt: now,
            buildCompletedAt: completedAt,
            createdAt: now
        )

        playerBuildings.append(newBuilding)

        // 8. 启动倒计时
        startBuildingTimer(newBuilding)

        print("[BuildingManager] ✅ 开始建造: \(template.name)，预计完成时间: \(completedAt)")
        return .success(newBuilding)
    }

    // MARK: - 完成建造

    /// 将建筑状态更新为已完成
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async {
        do {
            try await supabase.from("player_buildings")
                .update(["status": "active", "build_completed_at": Date().ISO8601Format()])
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地数组
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                playerBuildings[index].status = .active
                playerBuildings[index].buildCompletedAt = Date()
                print("[BuildingManager] ✅ 建筑完成: \(playerBuildings[index].buildingName)")
            }

            // 清理定时器
            buildingTimers.removeValue(forKey: buildingId)
        } catch {
            print("[BuildingManager] ❌ 更新建筑状态失败: \(error)")
            errorMessage = "更新建筑状态失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 升级建筑

    /// 升级指定建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 成功时返回更新后的建筑，失败时返回错误
    func upgradeBuilding(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {
        // 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            return .failure(.templateNotFound)
        }

        var building = playerBuildings[index]

        // 检查状态
        guard building.status == .active else {
            return .failure(.invalidStatus)
        }

        // 检查是否达到最大等级
        guard let template = getTemplate(for: building.templateId) else {
            return .failure(.templateNotFound)
        }
        guard building.level < template.maxLevel else {
            return .failure(.maxLevelReached)
        }

        let newLevel = building.level + 1

        do {
            try await supabase.from("player_buildings")
                .update(["level": newLevel])
                .eq("id", value: buildingId.uuidString)
                .execute()

            building.level = newLevel
            playerBuildings[index] = building
            print("[BuildingManager] ✅ 建筑升级: \(building.buildingName) → Lv.\(newLevel)")
            return .success(building)
        } catch {
            print("[BuildingManager] ❌ 升级建筑失败: \(error)")
            errorMessage = "升级失败: \(error.localizedDescription)"
            return .failure(.templateNotFound)
        }
    }

    // MARK: - 获取玩家建筑列表

    /// 获取指定领地的玩家建筑
    /// - Parameter territoryId: 领地 ID
    func fetchPlayerBuildings(territoryId: String) async {
        guard let userId = AuthManager.shared.currentUserId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await supabase
                .from("player_buildings")
                .select()
                .eq("territory_id", value: territoryId)
                .eq("user_id", value: userId.uuidString)
                .execute()

            let result = try decoder.decode([PlayerBuilding].self, from: response.data)

            playerBuildings = result
            print("[BuildingManager] ✅ 获取到 \(result.count) 个建筑")

            let now = Date()

            for building in playerBuildings {
                if building.status == .constructing {
                    if let completedAt = building.buildCompletedAt, completedAt <= now {
                        // App 重启时自动完成已过期的建筑
                        await completeConstruction(buildingId: building.id)
                    } else {
                        // 仍在建造中，重新启动倒计时
                        startBuildingTimer(building)
                    }
                }
            }
        } catch {
            print("[BuildingManager] ❌ 获取建筑列表失败: \(error)")
            errorMessage = "获取建筑列表失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 倒计时定时器

    /// 启动建造倒计时
    private func startBuildingTimer(_ building: PlayerBuilding) {
        guard let completedAt = building.buildCompletedAt else { return }

        let delay = completedAt.timeIntervalSinceNow

        guard delay > 0 else {
            Task { await completeConstruction(buildingId: building.id) }
            return
        }

        // 取消旧定时器，防止重复触发
        buildingTimers[building.id]?.cancel()

        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await completeConstruction(buildingId: building.id)
        }

        buildingTimers[building.id] = task
        print("[BuildingManager] ⏱ 建造倒计时启动: \(building.buildingName)，剩余 \(Int(delay))s")
    }

    // MARK: - 拆除建筑

    /// 拆除指定建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 是否拆除成功
    func demolishBuilding(buildingId: UUID) async -> Bool {
        do {
            try await supabase.from("player_buildings")
                .delete().eq("id", value: buildingId.uuidString).execute()
            buildingTimers[buildingId]?.cancel()
            buildingTimers.removeValue(forKey: buildingId)
            playerBuildings.removeAll { $0.id == buildingId }
            print("[BuildingManager] ✅ 拆除建筑: \(buildingId)")
            return true
        } catch {
            print("[BuildingManager] ❌ 拆除失败: \(error)")
            errorMessage = "拆除失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 辅助方法

    /// 根据 templateId 查找模板
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        buildingTemplates.first { $0.templateId == templateId }
    }

    /// 获取指定领地的所有建筑
    func buildings(in territoryId: String) -> [PlayerBuilding] {
        playerBuildings.filter { $0.territoryId == territoryId }
    }
}

// MARK: - 私有辅助类型

private extension BuildingManager {
    struct TemplatesContainer: Codable {
        let version: String
        let templates: [BuildingTemplate]
    }
}
