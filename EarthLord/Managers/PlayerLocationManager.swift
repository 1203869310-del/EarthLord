//
//  PlayerLocationManager.swift
//  EarthLord
//
//  玩家位置管理器 - 负责位置上报、附近玩家查询、密度计算
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 玩家位置管理器

@MainActor
final class PlayerLocationManager: ObservableObject {

    // MARK: - 单例

    static let shared = PlayerLocationManager()

    // MARK: - 发布属性

    /// 附近玩家数量（不含自己）
    @Published private(set) var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published private(set) var densityLevel: DensityLevel = .solo

    /// 是否正在上报
    @Published private(set) var isReporting: Bool = false

    /// 最后一次上报时间
    @Published private(set) var lastReportTime: Date?

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 定时上报计时器
    private var reportTimer: Timer?

    /// 位置管理器引用
    private weak var locationManager: LocationManager?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    // MARK: - 常量

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 移动阈值（米）- 超过此距离立即上报
    private let movementThreshold: Double = 50.0

    /// 在线判定阈值（秒）- 超过此时间未上报视为离线
    private let onlineThreshold: TimeInterval = 300.0  // 5分钟

    /// 查询半径（米）
    private let queryRadius: Double = 1000.0  // 1公里

    // MARK: - 初始化

    private init() {
        print("📍 [PlayerLocation] 玩家位置管理器已初始化")
    }

    // MARK: - 公开方法

    /// 设置位置管理器引用
    func setLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
    }

    /// 上报当前位置
    /// - Parameter location: 当前坐标
    func reportLocation(_ location: CLLocationCoordinate2D) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            print("⚠️ [PlayerLocation] 未登录，无法上报位置")
            return
        }

        isReporting = true
        defer { isReporting = false }

        // 构建上报数据
        let now = Date()
        let data: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "latitude": .double(location.latitude),
            "longitude": .double(location.longitude),
            "last_updated_at": .string(now.ISO8601Format()),
            "is_online": .bool(true)
        ]

        do {
            try await supabase
                .from("player_locations")
                .upsert(data, onConflict: "user_id")
                .execute()

            lastReportedLocation = location
            lastReportTime = now

            print("✅ [PlayerLocation] 位置上报成功: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")
            TerritoryLogger.shared.log("位置上报成功", type: .success)

        } catch {
            print("❌ [PlayerLocation] 位置上报失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("位置上报失败: \(error.localizedDescription)", type: .error)
            errorMessage = "位置上报失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 标记当前用户为离线
    func markOffline() async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            return
        }

        let data: [String: AnyJSON] = [
            "is_online": .bool(false)
        ]

        do {
            try await supabase
                .from("player_locations")
                .update(data)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("📴 [PlayerLocation] 已标记为离线")
            TerritoryLogger.shared.log("已标记为离线", type: .info)

        } catch {
            print("❌ [PlayerLocation] 标记离线失败: \(error.localizedDescription)")
        }
    }

    /// 查询附近玩家数量
    /// - Parameters:
    ///   - center: 中心坐标
    ///   - radiusMeters: 查询半径（默认1000米）
    /// - Returns: 附近在线玩家数量（不含自己）
    func queryNearbyPlayers(
        center: CLLocationCoordinate2D,
        radiusMeters: Double = 1000
    ) async throws -> Int {
        guard let userId = AuthManager.shared.currentUserId else {
            print("⚠️ [PlayerLocation] 未登录，无法查询附近玩家")
            return 0
        }

        // 计算边界框（用于快速筛选）
        let latDelta = radiusMeters / 111000.0
        let lonDelta = radiusMeters / (111000.0 * cos(center.latitude * .pi / 180))

        let minLat = center.latitude - latDelta
        let maxLat = center.latitude + latDelta
        let minLon = center.longitude - lonDelta
        let maxLon = center.longitude + lonDelta

        // 计算5分钟前的时间阈值
        let threshold = Date().addingTimeInterval(-onlineThreshold)
        let thresholdStr = threshold.ISO8601Format()

        print("🔍 [PlayerLocation] 查询附近玩家...")
        print("🔍 [PlayerLocation] 中心: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")
        print("🔍 [PlayerLocation] 半径: \(radiusMeters)m")
        print("🔍 [PlayerLocation] 时间阈值: \(thresholdStr)")

        do {
            // 查询边界框内、在线、5分钟内活跃、排除自己的玩家
            let response: [PlayerLocation] = try await supabase
                .from("player_locations")
                .select()
                .gte("latitude", value: minLat)
                .lte("latitude", value: maxLat)
                .gte("longitude", value: minLon)
                .lte("longitude", value: maxLon)
                .eq("is_online", value: true)
                .gte("last_updated_at", value: thresholdStr)
                .neq("user_id", value: userId.uuidString)
                .execute()
                .value

            print("🔍 [PlayerLocation] 边界框内找到 \(response.count) 个候选玩家")

            // 精确距离过滤
            let nearbyPlayers = response.filter { player in
                let distance = calculateDistance(
                    from: center,
                    to: CLLocationCoordinate2D(
                        latitude: player.latitude,
                        longitude: player.longitude
                    )
                )
                return distance <= radiusMeters
            }

            let count = nearbyPlayers.count
            nearbyPlayerCount = count
            densityLevel = DensityLevel.from(playerCount: count)

            print("✅ [PlayerLocation] 附近玩家数量: \(count), 密度等级: \(densityLevel.rawValue)")
            TerritoryLogger.shared.log("附近玩家: \(count)人 (\(densityLevel.rawValue))", type: .info)

            return count

        } catch {
            print("❌ [PlayerLocation] 查询附近玩家失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("查询失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 开始定时上报位置
    func startPeriodicReporting() {
        // 先停止已有的计时器
        stopPeriodicReporting()

        print("🔄 [PlayerLocation] 开始定时上报（间隔: \(reportInterval)秒）")
        TerritoryLogger.shared.log("开始定时位置上报", type: .info)

        // 立即上报一次
        Task {
            await reportCurrentLocationIfNeeded()
        }

        // 启动定时器
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reportCurrentLocationIfNeeded()
            }
        }
    }

    /// 停止定时上报
    func stopPeriodicReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
        print("⏹️ [PlayerLocation] 停止定时上报")
    }

    /// 检查是否需要立即上报（移动超过阈值）
    /// - Parameter newLocation: 新位置
    /// - Returns: 是否需要立即上报
    func shouldReportImmediately(newLocation: CLLocationCoordinate2D) -> Bool {
        guard let lastLocation = lastReportedLocation else {
            return true  // 首次上报
        }

        let distance = calculateDistance(from: lastLocation, to: newLocation)
        return distance >= movementThreshold
    }

    // MARK: - 私有方法

    /// 上报当前位置（如果有）
    private func reportCurrentLocationIfNeeded() async {
        guard let location = locationManager?.userLocation else {
            print("⚠️ [PlayerLocation] 无法获取当前位置")
            return
        }

        do {
            try await reportLocation(location)
        } catch {
            // 错误已在 reportLocation 中记录
        }
    }

    /// 计算两点之间的距离（米）
    /// - Parameters:
    ///   - from: 起点
    ///   - to: 终点
    /// - Returns: 距离（米）
    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}
