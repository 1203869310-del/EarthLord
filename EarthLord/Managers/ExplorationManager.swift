//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器 - 管理探索会话、距离追踪、POI搜刮、奖励生成
//

import Foundation
import CoreLocation
import Combine

// MARK: - 探索会话状态

/// 探索会话状态
enum ExplorationState {
    case idle           // 空闲
    case active         // 进行中
    case completed      // 已完成
}

// MARK: - 探索管理器

@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ExplorationManager()

    // MARK: - Published Properties

    /// 当前探索状态
    @Published var state: ExplorationState = .idle

    /// 累计行走距离（米）
    @Published var totalDistance: Double = 0

    /// 当前奖励等级
    @Published var currentTier: RewardTier = .none

    /// 探索开始时间
    @Published var startTime: Date?

    /// 探索持续时间（秒）
    @Published var duration: TimeInterval = 0

    /// 最后一次探索结果
    @Published var lastExplorationResult: ExplorationResult?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 速度警告
    @Published var speedWarning: String?

    // MARK: - 玩家密度相关 Published Properties

    /// 当前密度等级
    @Published var densityLevel: DensityLevel = .solo

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    // MARK: - POI 相关 Published Properties

    /// 当前 POI 列表
    @Published var pois: [POI] = []

    /// 是否正在搜索 POI
    @Published var isSearchingPOI: Bool = false

    /// 是否显示 POI 接近弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前接近的 POI
    @Published var currentPOI: POI?

    /// 搜刮结果
    @Published var scavengeResult: ScavengeResult?

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 已搜刮的 POI ID 列表（本次探索中）
    @Published var scavengedPOIIds: Set<UUID> = []

    // MARK: - Private Properties

    /// 上一个位置
    private var lastLocation: CLLocation?

    /// 上一次位置更新时间
    private var lastLocationTime: Date?

    /// 计时器
    private var timer: Timer?

    /// 位置管理器（引用外部）
    private weak var locationManager: LocationManager?

    /// 玩家位置管理器
    private let playerLocationManager = PlayerLocationManager.shared

    /// 速度检测连续次数
    private var consecutiveHighSpeedCount = 0

    /// 超速开始时间
    private var overspeedStartTime: Date?

    /// 超速警告计时器
    private var overspeedTimer: Timer?

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 地理围栏管理器（用于 POI 接近检测）
    private var geofenceManager: CLLocationManager?

    /// 地理围栏代理
    private var geofenceDelegate: GeofenceDelegate?

    /// 活跃的地理围栏区域
    private var activeRegions: [String: CLCircularRegion] = [:]

    // MARK: - Constants

    /// 最大允许速度（km/h）
    private let maxSpeed: Double = 30.0

    /// GPS 精度阈值（米）
    private let minAccuracy: Double = 50.0

    /// 最小移动距离（米）
    private let minMovementDistance: Double = 5.0

    /// 最小更新间隔（秒）
    private let minUpdateInterval: TimeInterval = 1.0

    /// 超速警告时长（秒）
    private let overspeedWarningDuration: TimeInterval = 10.0

    /// POI 触发距离（米）
    private let poiTriggerDistance: Double = 50.0

    // MARK: - Initialization

    private init() {
        setupGeofenceManager()
    }

    /// 设置地理围栏管理器
    private func setupGeofenceManager() {
        geofenceManager = CLLocationManager()
        geofenceDelegate = GeofenceDelegate { [weak self] regionId in
            Task { @MainActor in
                self?.handleRegionEntered(regionId: regionId)
            }
        }
        geofenceManager?.delegate = geofenceDelegate
    }

    // MARK: - Public Methods

    /// 设置位置管理器
    func setLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
    }

    /// 开始探索
    func startExploration() {
        guard state == .idle else {
            print("⚠️ [探索] 探索已在进行中")
            return
        }

        // 重置状态
        totalDistance = 0
        currentTier = .none
        currentSpeed = 0
        startTime = Date()
        duration = 0
        lastLocation = nil
        lastLocationTime = nil
        isOverSpeed = false
        speedWarning = nil
        consecutiveHighSpeedCount = 0
        overspeedStartTime = nil
        overspeedTimer?.invalidate()
        overspeedTimer = nil

        // 重置密度状态
        densityLevel = .solo
        nearbyPlayerCount = 0

        // 重置 POI 状态
        pois = []
        showPOIPopup = false
        currentPOI = nil
        scavengeResult = nil
        showScavengeResult = false
        scavengedPOIIds = []
        clearAllGeofences()

        // 更新状态
        state = .active

        // 启动计时器（每秒更新一次）
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }

        print("🚀 [探索] 开始探索")
        print("📋 [探索] 初始状态 - 距离: 0m, 等级: 无奖励, 速度限制: \(maxSpeed)km/h")
        TerritoryLogger.shared.log("开始探索 - 速度限制: \(maxSpeed)km/h", type: .info)

        // 设置位置管理器引用到 PlayerLocationManager
        if let manager = locationManager {
            playerLocationManager.setLocationManager(manager)
        }

        // 开始定时位置上报
        playerLocationManager.startPeriodicReporting()

        // 搜索附近玩家并设置 POI
        Task {
            await queryDensityAndSetupPOIs()
        }
    }

    /// 查询玩家密度并设置 POI
    private func queryDensityAndSetupPOIs() async {
        guard let location = locationManager?.userLocation else {
            print("⚠️ [POI] 无法获取当前位置")
            TerritoryLogger.shared.log("POI搜索失败：无法获取位置", type: .error)
            return
        }

        isSearchingPOI = true

        // 步骤1：上报当前位置
        do {
            try await playerLocationManager.reportLocation(location)
            print("✅ [密度] 位置上报成功")
        } catch {
            print("⚠️ [密度] 位置上报失败（不影响探索）: \(error.localizedDescription)")
        }

        // 步骤2：查询附近玩家数量
        do {
            let count = try await playerLocationManager.queryNearbyPlayers(center: location)
            nearbyPlayerCount = count
            densityLevel = DensityLevel.from(playerCount: count)

            print("📊 [密度] 附近玩家: \(count)人, 密度等级: \(densityLevel.rawValue)")
            TerritoryLogger.shared.log("附近\(count)人 (\(densityLevel.rawValue))", type: .info)

        } catch {
            // 查询失败时使用默认值（独行者）
            print("⚠️ [密度] 查询失败（使用默认值）: \(error.localizedDescription)")
            nearbyPlayerCount = 0
            densityLevel = .solo
        }

        // 步骤3：根据密度搜索 POI
        do {
            let maxPOICount = densityLevel.suggestedPOICount
            print("🔍 [POI] 根据密度(\(densityLevel.rawValue))搜索POI，最大数量: \(maxPOICount == Int.max ? "不限" : "\(maxPOICount)")")

            let foundPOIs = try await POISearchManager.shared.searchNearbyPOIs(
                center: location,
                maxCount: maxPOICount
            )

            // 更新 POI 列表
            pois = foundPOIs

            // 为每个 POI 设置地理围栏
            setupGeofences(for: foundPOIs)

            print("✅ [POI] 成功加载 \(foundPOIs.count) 个 POI，已设置地理围栏")
            TerritoryLogger.shared.log("加载 \(foundPOIs.count) 个 POI (密度: \(densityLevel.rawValue))", type: .success)

        } catch {
            print("❌ [POI] 搜索失败: \(error)")
            TerritoryLogger.shared.log("POI搜索失败: \(error.localizedDescription)", type: .error)
        }

        isSearchingPOI = false
    }

    /// 为 POI 列表设置地理围栏
    private func setupGeofences(for pois: [POI]) {
        guard let manager = geofenceManager else { return }

        for poi in pois {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: poiTriggerDistance,
                identifier: poi.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            manager.startMonitoring(for: region)
            activeRegions[poi.id.uuidString] = region

            print("📍 [围栏] 设置围栏: \(poi.name) (半径: \(poiTriggerDistance)m)")
        }

        print("🔲 [围栏] 共设置 \(activeRegions.count) 个地理围栏")
    }

    /// 清除所有地理围栏
    private func clearAllGeofences() {
        guard let manager = geofenceManager else { return }

        for (_, region) in activeRegions {
            manager.stopMonitoring(for: region)
        }

        activeRegions.removeAll()
        print("🧹 [围栏] 已清除所有地理围栏")
    }

    /// 处理进入地理围栏事件
    private func handleRegionEntered(regionId: String) {
        guard state == .active else { return }

        // 查找对应的 POI
        guard let poi = pois.first(where: { $0.id.uuidString == regionId }) else {
            print("⚠️ [围栏] 找不到对应的 POI: \(regionId)")
            return
        }

        // 检查是否已经搜刮过
        if scavengedPOIIds.contains(poi.id) {
            print("ℹ️ [围栏] POI 已搜刮: \(poi.name)")
            return
        }

        // 如果已经有弹窗显示，忽略
        if showPOIPopup {
            print("ℹ️ [围栏] 弹窗已显示，忽略: \(poi.name)")
            return
        }

        // 显示搜刮弹窗
        currentPOI = poi
        showPOIPopup = true

        print("🎯 [围栏] 进入 POI 范围: \(poi.name)")
        TerritoryLogger.shared.log("发现地点: \(poi.name)", type: .info)
    }

    /// 停止探索
    func stopExploration() {
        guard state == .active else {
            print("⚠️ [探索] 没有进行中的探索")
            return
        }

        // 停止计时器
        timer?.invalidate()
        timer = nil
        overspeedTimer?.invalidate()
        overspeedTimer = nil

        // 停止位置上报
        playerLocationManager.stopPeriodicReporting()

        // 上报最终位置并标记离线
        Task {
            if let location = locationManager?.userLocation {
                try? await playerLocationManager.reportLocation(location)
            }
            try? await playerLocationManager.markOffline()
        }

        // 清除 POI 地理围栏
        clearAllGeofences()

        // 关闭 POI 弹窗
        showPOIPopup = false
        showScavengeResult = false

        print("⏹️ [探索] 停止探索")
        print("📊 [探索] 最终统计 - 距离: \(String(format: "%.0f", totalDistance))m, 时长: \(String(format: "%.0f", duration))秒")
        TerritoryLogger.shared.log("停止探索 - 距离: \(String(format: "%.0f", totalDistance))m", type: .info)

        // 计算最终奖励
        let finalTier = RewardTier.tier(for: totalDistance)
        let rewards = RewardGenerator.generateRewards(tier: finalTier)

        print("🎁 [探索] 奖励等级: \(finalTier.rawValue), 物品数量: \(rewards.count)")
        TerritoryLogger.shared.log("探索完成 - 距离: \(String(format: "%.0f", totalDistance))m, 等级: \(finalTier.rawValue)", type: .success)

        // 生成探索结果（去掉area相关）
        let result = ExplorationResult(
            distance: ExplorationStat(
                current: totalDistance,
                total: totalDistance,
                rank: Int.random(in: 30...60)
            ),
            area: ExplorationStat(  // 暂时保留以兼容现有数据结构
                current: 0,
                total: 0,
                rank: 0
            ),
            duration: Int(duration / 60), // 转换为分钟
            rewardTier: finalTier,
            rewards: rewards
        )

        lastExplorationResult = result

        // 添加奖励到背包
        for reward in rewards {
            InventoryManager.shared.addItem(
                name: reward.name,
                category: reward.category,
                quantity: reward.quantity,
                rarity: reward.rarity
            )
        }

        // 更新状态
        state = .completed

        print("✅ [探索] 探索结束 - 距离: \(String(format: "%.0f", totalDistance))m, 等级: \(finalTier.rawValue)")
        TerritoryLogger.shared.log("探索结束 - \(String(format: "%.0f", totalDistance))m - \(finalTier.rawValue)", type: .success)
    }

    /// 处理位置更新
    func handleLocationUpdate(_ location: CLLocation) {
        guard state == .active else {
            return
        }

        let now = Date()

        // 日志：收到GPS更新
        print("📍 [GPS] 位置更新 - 精度: \(String(format: "%.1f", location.horizontalAccuracy))m, 坐标: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")

        // 检查 GPS 精度
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < minAccuracy else {
            print("⚠️ [GPS] 精度不足: \(String(format: "%.1f", location.horizontalAccuracy))m (要求 < \(minAccuracy)m) - 忽略此点")
            TerritoryLogger.shared.log("GPS精度不足: \(String(format: "%.1f", location.horizontalAccuracy))m", type: .warning)
            return
        }

        // 如果是第一个点，只记录位置
        guard let lastLoc = lastLocation, let lastTime = lastLocationTime else {
            lastLocation = location
            lastLocationTime = now
            print("✅ [GPS] 记录初始位置")
            return
        }

        // 计算时间差
        let timeDelta = now.timeIntervalSince(lastTime)

        // 检查时间间隔是否太短（按文档要求至少1秒）
        guard timeDelta >= minUpdateInterval else {
            print("⏱️ [GPS] 更新间隔太短: \(String(format: "%.2f", timeDelta))秒 - 忽略")
            return
        }

        // 计算距离
        let distance = location.distance(from: lastLoc)

        // 日志：距离计算
        print("📏 [距离] 本次移动: \(String(format: "%.1f", distance))m, 时间间隔: \(String(format: "%.1f", timeDelta))秒")

        // 检查距离跳变（按文档要求100米阈值）
        if distance > 100 {
            print("🔄 [GPS] 距离跳变: \(String(format: "%.1f", distance))m (超过100m阈值) - 忽略此点")
            TerritoryLogger.shared.log("GPS跳变: \(String(format: "%.0f", distance))m", type: .warning)
            return
        }

        // 检查距离是否太小
        guard distance >= minMovementDistance else {
            print("🔍 [距离] 移动距离太小: \(String(format: "%.1f", distance))m (< \(minMovementDistance)m) - 忽略")
            return
        }

        // 计算速度（km/h）
        let speed = (distance / timeDelta) * 3.6
        currentSpeed = speed

        // 日志：速度计算
        print("🚶 [速度] 当前速度: \(String(format: "%.1f", speed)) km/h (限制: \(maxSpeed) km/h)")

        // 速度异常检测（极端情况，可能是GPS错误）
        if speed > 100 {
            print("❌ [速度] 速度异常: \(String(format: "%.1f", speed)) km/h (超过100km/h) - 判定为GPS错误，忽略")
            TerritoryLogger.shared.log("GPS异常: 速度\(String(format: "%.0f", speed))km/h", type: .error)
            return
        }

        // 超速检测（30km/h限制）
        if speed > maxSpeed {
            // 如果是首次超速，开始计时
            if overspeedStartTime == nil {
                overspeedStartTime = now
                speedWarning = "速度过快！请降低速度，10秒后若未降速将停止探索"

                print("⚠️ [超速] 检测到超速: \(String(format: "%.1f", speed)) km/h - 开始10秒倒计时")
                TerritoryLogger.shared.log("超速警告: \(String(format: "%.1f", speed))km/h", type: .warning)

                // 启动10秒计时器
                overspeedTimer?.invalidate()
                overspeedTimer = Timer.scheduledTimer(withTimeInterval: overspeedWarningDuration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.handleOverspeedTimeout()
                    }
                }
            } else {
                // 继续超速中
                let elapsedTime = now.timeIntervalSince(overspeedStartTime!)
                let remainingTime = overspeedWarningDuration - elapsedTime

                if remainingTime > 0 {
                    speedWarning = "速度过快！还有 \(Int(remainingTime)) 秒降低速度"
                    print("⚠️ [超速] 持续超速: \(String(format: "%.1f", speed)) km/h, 剩余时间: \(Int(remainingTime))秒")
                }
            }
        } else {
            // 速度正常，清除超速状态
            if overspeedStartTime != nil {
                print("✅ [速度] 速度已降低: \(String(format: "%.1f", speed)) km/h - 取消超速警告")
                TerritoryLogger.shared.log("速度恢复正常", type: .success)

                overspeedStartTime = nil
                overspeedTimer?.invalidate()
                overspeedTimer = nil
                speedWarning = nil
            }
        }

        // 累加距离
        let oldDistance = totalDistance
        totalDistance += distance

        // 日志：距离累加
        print("📏 [距离] 累计距离: \(String(format: "%.0f", oldDistance))m → \(String(format: "%.0f", totalDistance))m (+\(String(format: "%.1f", distance))m)")

        // 更新奖励等级
        let oldTier = currentTier
        currentTier = RewardTier.tier(for: totalDistance)

        // 如果等级提升，记录日志
        if currentTier != oldTier {
            print("🎖️ [等级] 奖励等级提升: \(oldTier.rawValue) → \(currentTier.rawValue)")
            TerritoryLogger.shared.log("等级提升: \(currentTier.rawValue)", type: .success)
        }

        // 更新位置和时间
        lastLocation = location
        lastLocationTime = now

        // 总结日志
        print("📊 [探索] 当前状态 - 距离: \(String(format: "%.0f", totalDistance))m, 等级: \(currentTier.rawValue), 速度: \(String(format: "%.1f", speed))km/h")
    }

    /// 处理超速超时（10秒后仍超速）
    private func handleOverspeedTimeout() {
        guard state == .active else { return }

        print("❌ [超速] 10秒超时 - 探索失败")
        TerritoryLogger.shared.log("超速超时，探索失败", type: .error)

        isOverSpeed = true
        speedWarning = "速度过快，探索失败"

        // 停止探索
        stopExploration()

        // 重置状态为idle，不保存结果
        state = .idle
        lastExplorationResult = nil
    }

    /// 重置为空闲状态
    func reset() {
        state = .idle
        lastExplorationResult = nil
        isOverSpeed = false
        speedWarning = nil

        // 重置密度状态
        densityLevel = .solo
        nearbyPlayerCount = 0

        // 停止位置上报
        playerLocationManager.stopPeriodicReporting()

        // 清除 POI 状态
        pois = []
        showPOIPopup = false
        currentPOI = nil
        scavengeResult = nil
        showScavengeResult = false
        scavengedPOIIds = []
        clearAllGeofences()
    }

    // MARK: - POI 搜刮方法

    /// 执行搜刮
    func scavengePOI() {
        guard let poi = currentPOI else {
            print("⚠️ [搜刮] 没有当前 POI")
            return
        }

        // 关闭接近弹窗
        showPOIPopup = false

        // 标记为已搜刮
        scavengedPOIIds.insert(poi.id)

        // 生成奖励（根据 POI 类型生成对应奖励）
        let rewards = RewardGenerator.generatePOIRewards(poiType: poi.type)

        // 创建搜刮结果
        let result = ScavengeResult(
            poi: poi,
            rewards: rewards,
            timestamp: Date()
        )

        // 显示搜刮结果
        scavengeResult = result
        showScavengeResult = true

        // 将奖励添加到背包
        for reward in rewards {
            InventoryManager.shared.addItem(
                name: reward.name,
                category: reward.category,
                quantity: reward.quantity,
                rarity: reward.rarity
            )
        }

        print("🎁 [搜刮] 搜刮成功: \(poi.name), 获得 \(rewards.count) 件物品")
        TerritoryLogger.shared.log("搜刮 \(poi.name): 获得 \(rewards.count) 件物品", type: .success)

        // 更新 POI 状态
        if let index = pois.firstIndex(where: { $0.id == poi.id }) {
            pois[index].status = .looted
            pois[index].lastScavengedAt = Date()
        }
    }

    /// 关闭 POI 接近弹窗
    func dismissPOIPopup() {
        showPOIPopup = false
        currentPOI = nil
    }

    /// 关闭搜刮结果弹窗
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeResult = nil
        currentPOI = nil
    }

    /// 计算当前位置到 POI 的距离
    func distanceToPOI(_ poi: POI) -> Double {
        guard let userLocation = locationManager?.userLocation else {
            return 0
        }

        let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        return userCLLocation.distance(from: poiLocation)
    }

    // MARK: - Private Methods

    /// 更新探索持续时间
    private func updateDuration() {
        guard let start = startTime else { return }
        duration = Date().timeIntervalSince(start)
    }
}

// MARK: - 地理围栏代理

/// 地理围栏代理
/// 用于处理 CLLocationManager 的地理围栏事件
class GeofenceDelegate: NSObject, CLLocationManagerDelegate {

    /// 进入区域回调
    private let onRegionEntered: (String) -> Void

    init(onRegionEntered: @escaping (String) -> Void) {
        self.onRegionEntered = onRegionEntered
        super.init()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("📍 [围栏代理] 进入区域: \(region.identifier)")
        onRegionEntered(region.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("📍 [围栏代理] 离开区域: \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ [围栏代理] 监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("✅ [围栏代理] 开始监控: \(region.identifier)")
    }
}
