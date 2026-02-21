//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 负责获取和管理用户位置 + 路径追踪
//

import Foundation
import CoreLocation
import Combine  // @Published 需要这个框架
import UIKit    // UIApplication 需要这个框架

// MARK: - LocationManager

/// GPS 定位管理器
/// 负责请求定位权限、获取用户位置、处理授权状态变化、路径追踪
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = LocationManager()

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪 Published Properties

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否已闭合
    @Published var isPathClosed: Bool = false

    // MARK: - 验证状态 Published Properties

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 速度检测 Published Properties

    /// 速度警告信息（超速时显示）
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 路径碰撞检测 Published Properties

    /// 路径碰撞警告信息
    @Published var pathCollisionWarning: String?

    /// 当前预警级别
    @Published var currentWarningLevel: TerritoryWarningLevel = .safe

    /// 距离最近领地的距离
    @Published var distanceToNearestTerritory: Double?

    // MARK: - Private Properties

    /// 缓存的他人领地数据（用于路径碰撞检测）
    private var cachedOthersTerritories: [Territory] = []

    /// 综合检测定时器（每10秒检测一次）
    private var comprehensiveCheckTimer: Timer?

    /// 综合检测间隔（秒）
    private let comprehensiveCheckInterval: TimeInterval = 10.0

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（Timer 采点需要用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 最小移动距离（米）
    private let minimumDistance: CLLocationDistance = 10.0

    /// 闭环距离阈值（米）- 当前位置距起点小于此值判定为闭环
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数 - 少于此值不进行闭环检测
    private let minimumPathPoints: Int = 10

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 上次位置（用于计算速度）
    private var lastLocation: CLLocation?

    /// 上次位置时间戳（用于计算时间差）
    private var lastLocationTimestamp: Date?

    // MARK: - Computed Properties

    /// 是否已获得定位授权
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否被用户拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 是否尚未决定（首次请求）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 当前路径点数
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - Initialization

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动5米才更新位置
    }

    // MARK: - Public Methods

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        // 清除之前的错误
        locationError = nil

        // 请求"使用App期间"定位权限
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新用户位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "未获得定位授权"
            return
        }

        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新用户位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// 打开系统设置页面（用于用户拒绝权限后引导开启）
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }

        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "未获得定位授权，无法开始圈地"
            return
        }

        // 重置路径状态
        isTracking = true
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocation = nil
        lastLocationTimestamp = nil
        consecutiveHighSpeedCount = 0

        // 重置路径碰撞检测状态
        pathCollisionWarning = nil
        cachedOthersTerritories = []
        currentWarningLevel = .safe
        distanceToNearestTerritory = nil

        // 确保定位正在运行
        startUpdatingLocation()

        // 立即记录第一个点（如果有位置的话）
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 [路径追踪] 记录起始点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        // 启动采点定时器，每 2 秒采点一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordPathPoint()
            }
        }

        // 启动综合检测定时器，每 10 秒检测一次
        comprehensiveCheckTimer = Timer.scheduledTimer(withTimeInterval: comprehensiveCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performComprehensiveCheck()
            }
        }

        print("🚀 [路径追踪] 开始追踪，采点间隔: \(trackingInterval)秒，综合检测间隔: \(comprehensiveCheckInterval)秒")

        // 【日志】记录开始追踪
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 【异步】加载他人领地数据用于路径碰撞检测
        Task { @MainActor in
            await loadOthersTerritoriesForCollisionCheck()
            // 加载完后立即进行一次检测
            await performComprehensiveCheck()
        }
    }

    /// 停止路径追踪
    /// 会重置所有追踪和验证状态，防止重复上传
    func stopPathTracking() {
        // 停止采点定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 停止综合检测定时器
        comprehensiveCheckTimer?.invalidate()
        comprehensiveCheckTimer = nil

        let pointCount = pathCoordinates.count

        // 重置追踪状态
        isTracking = false
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocation = nil
        lastLocationTimestamp = nil
        consecutiveHighSpeedCount = 0

        // 重置路径碰撞检测状态
        pathCollisionWarning = nil
        cachedOthersTerritories = []
        currentWarningLevel = .safe
        distanceToNearestTerritory = nil

        print("🛑 [路径追踪] 停止追踪，共记录 \(pointCount) 个点，所有状态已重置")

        // 【日志】记录停止追踪
        TerritoryLogger.shared.log("停止追踪，共 \(pointCount) 个点，状态已重置", type: .info)
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        print("🗑️ [路径追踪] 已清除路径")
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 如果已闭环，停止记录
        guard !isPathClosed else {
            print("✅ [路径追踪] 已闭环，停止记录新点")
            return
        }

        // 检查是否有当前位置
        guard let location = currentLocation else {
            print("⚠️ [路径追踪] 当前位置为空，跳过采点")
            return
        }

        // 【速度检测】检查移动速度是否正常
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ [路径追踪] 速度检测未通过，跳过采点")
            return
        }

        // 检查是否需要记录（距离判断）
        var distanceFromLast: Double = 0
        if let lastCoordinate = pathCoordinates.last {
            let lastLoc = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            distanceFromLast = location.distance(from: lastLoc)

            // 距离小于最小阈值，跳过
            if distanceFromLast < minimumDistance {
                print("📏 [路径追踪] 移动距离 \(String(format: "%.1f", distanceFromLast))米 < \(minimumDistance)米，跳过")
                return
            }

            print("📏 [路径追踪] 移动距离 \(String(format: "%.1f", distanceFromLast))米，记录新点")
        }

        // 记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        print("📍 [路径追踪] 记录第 \(pathCoordinates.count) 个点: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        // 【日志】记录新点
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)

        // 【闭环检测】检查是否形成闭环
        checkPathClosure()
    }

    /// 连续高速计数器（防止单次 GPS 跳变触发误判）
    private var consecutiveHighSpeedCount: Int = 0

    // MARK: - 速度检测方法

    /// 验证移动速度是否正常
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常可以记录，false 表示超速需要跳过
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        let now = Date()

        // 【GPS 精度检查】精度太差的点直接跳过，不更新 lastLocation
        // horizontalAccuracy > 20 米表示精度较差，可能是 GPS 跳变（收紧阈值）
        if newLocation.horizontalAccuracy > 20 || newLocation.horizontalAccuracy < 0 {
            print("⚠️ [速度检测] GPS 精度差: \(String(format: "%.1f", newLocation.horizontalAccuracy))m，跳过此点")
            return false
        }

        // 如果是第一个点，记录位置和时间，直接通过
        guard let prevLocation = lastLocation, let prevTimestamp = lastLocationTimestamp else {
            lastLocation = newLocation
            lastLocationTimestamp = now
            consecutiveHighSpeedCount = 0
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: prevLocation)

        // 计算时间差（秒）
        let timeDelta = now.timeIntervalSince(prevTimestamp)

        // 防止除零错误，时间间隔太短时跳过
        guard timeDelta > 0.5 else {
            return false
        }

        // 计算速度（km/h）= 距离(m) ÷ 时间(s) × 3.6
        let speedKmh = (distance / timeDelta) * 3.6

        print("🚗 [速度检测] 距离: \(String(format: "%.1f", distance))m, 时间: \(String(format: "%.1f", timeDelta))s, 速度: \(String(format: "%.1f", speedKmh)) km/h, GPS精度: \(String(format: "%.1f", newLocation.horizontalAccuracy))m")

        // 【GPS 跳变检测 1】速度超过 100 km/h 几乎肯定是 GPS 跳变
        // 人类极限跑步约 45 km/h，骑车约 60 km/h，100+ 必定是噪声
        if speedKmh > 100 {
            print("🔄 [速度检测] 速度异常（\(String(format: "%.0f", speedKmh)) km/h），判定为 GPS 跳变，忽略此点")
            // 不更新 lastLocation，等待下一个正常点
            return false
        }

        // 【GPS 跳变检测 2】短时间内移动距离过大
        // 2秒内移动超过 40 米（相当于 72 km/h）几乎肯定是 GPS 跳变
        if distance > 40 && timeDelta < 3 {
            print("🔄 [速度检测] 短时间大距离跳变（\(String(format: "%.0f", distance))m / \(String(format: "%.1f", timeDelta))s），忽略此点")
            return false
        }

        // 【GPS 跳变检测 3】长时间内移动距离过大
        // 5秒内移动超过 80 米也可能是 GPS 跳变
        if distance > 80 && timeDelta < 5 {
            print("🔄 [速度检测] 检测到 GPS 跳变（\(String(format: "%.0f", distance))m / \(String(format: "%.1f", timeDelta))s），忽略此点")
            return false
        }

        // 更新上次位置和时间戳
        lastLocation = newLocation
        lastLocationTimestamp = now

        // 速度 > 60 km/h，需要连续检测才判定为真正超速
        // 单次高速可能是 GPS 小幅跳变，连续高速才是真正开车
        if speedKmh > 60 {
            consecutiveHighSpeedCount += 1
            print("⚠️ [速度检测] 高速 \(String(format: "%.0f", speedKmh)) km/h，连续次数: \(consecutiveHighSpeedCount)")

            // 连续 3 次高速才判定为开车，停止追踪
            if consecutiveHighSpeedCount >= 3 {
                speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），追踪已暂停"
                isOverSpeed = true
                print("🚨 [速度检测] 连续高速 \(consecutiveHighSpeedCount) 次，判定为开车，停止追踪！")

                TerritoryLogger.shared.log("连续超速 \(consecutiveHighSpeedCount) 次，已停止追踪", type: .error)

                stopPathTracking()
                return false
            }

            // 未达到连续次数，显示警告但继续
            speedWarning = "移动速度较快（\(String(format: "%.0f", speedKmh)) km/h）"
            isOverSpeed = true
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.0f", speedKmh)) km/h (第 \(consecutiveHighSpeedCount) 次)", type: .warning)
            return true
        }

        // 速度正常，重置连续高速计数器
        consecutiveHighSpeedCount = 0

        // 速度正常，清除警告
        if isOverSpeed {
            speedWarning = nil
            isOverSpeed = false
        }

        return true
    }

    // MARK: - 闭环检测方法

    /// 检查路径是否形成闭环
    private func checkPathClosure() {
        // 【关键】已闭环则不再检测，防止重复触发
        guard !isPathClosed else { return }

        // 路径点数不足，不检测
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔄 [闭环检测] 点数 \(pathCoordinates.count) < \(minimumPathPoints)，跳过检测")
            return
        }

        // 获取起点和当前位置
        guard let startPoint = pathCoordinates.first,
              let currentLocation = currentLocation else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        print("🔄 [闭环检测] 距起点 \(String(format: "%.1f", distanceToStart)) 米")

        // 【日志】记录距起点距离（≥10个点后才记录）
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distanceToStart))m (需≤30m)", type: .info)

        // 距离 ≤ 阈值，判定为闭环
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发 UI 更新
            print("✅ [闭环检测] 闭环成功！距起点 \(String(format: "%.1f", distanceToStart)) 米 ≤ \(closureDistanceThreshold) 米")

            // 【日志】记录闭环成功
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distanceToStart))m", type: .success)

            // 【关键】闭环成功后自动进行领地验证
            let validationResult = validateTerritory()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离（米）
    /// - Returns: 路径总长度，单位为米
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<pathCoordinates.count - 1 {
            let current = CLLocation(latitude: pathCoordinates[i].latitude,
                                     longitude: pathCoordinates[i].longitude)
            let next = CLLocation(latitude: pathCoordinates[i + 1].latitude,
                                  longitude: pathCoordinates[i + 1].longitude)
            totalDistance += current.distance(from: next)
        }

        return totalDistance
    }

    /// 计算多边形面积（平方米）
    /// 使用鞋带公式（Shoelace formula）+ 球面修正
    /// - Returns: 多边形面积，单位为平方米
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        // 地球半径（米）
        let earthRadius: Double = 6371000

        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        // 取绝对值并乘以地球半径的平方，再除以2
        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D,
                                   p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D,
                                   p4: CLLocationCoordinate2D) -> Bool {
        /// CCW（逆时针）判断辅助函数
        /// 判断三点 A -> B -> C 是否为逆时针方向
        /// - 坐标映射：longitude = X轴，latitude = Y轴
        /// - 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        /// - 叉积 > 0 表示逆时针
        func ccw(_ A: CLLocationCoordinate2D,
                 _ B: CLLocationCoordinate2D,
                 _ C: CLLocationCoordinate2D) -> Bool {
            // 使用 longitude 作为 X，latitude 作为 Y
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断两线段是否相交的核心逻辑：
        // 当且仅当：ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 计算两点之间的距离（米）
    private func distanceBetween(_ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
        let loc2 = CLLocation(latitude: p2.latitude, longitude: p2.longitude)
        return loc1.distance(from: loc2)
    }

    /// 检测路径是否存在自相交
    /// - Returns: true 表示存在自相交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要 15 个点才检测自交
        // 点数太少时 GPS 噪声容易导致误判
        guard pathCoordinates.count >= 15 else {
            TerritoryLogger.shared.log("自交检测: 点数 \(pathCoordinates.count) < 15，跳过检测 ✓", type: .info)
            return false
        }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 15 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（增加到 4，更宽容）
        let skipHeadCount = 4
        let skipTailCount = 4

        // ✅ GPS 跳变线段阈值（米）- 超过此距离的线段被视为 GPS 噪声，跳过检测
        let maxValidSegmentLength: Double = 80.0

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // ✅ 跳过 GPS 跳变产生的长线段
            let segment1Length = distanceBetween(p1, p2)
            if segment1Length > maxValidSegmentLength {
                continue
            }

            // 从 i+2 开始比较（跳过相邻线段）
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止正常圈地被误判）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                // ✅ 跳过相邻太近的线段（间隔至少 3 条线段）
                if j - i < 4 {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                // ✅ 跳过 GPS 跳变产生的长线段
                let segment2Length = distanceBetween(p3, p4)
                if segment2Length > maxValidSegmentLength {
                    continue
                }

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1)(\(String(format: "%.0f", segment1Length))m) 与 线段\(j)-\(j+1)(\(String(format: "%.0f", segment2Length))m) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: 元组 (isValid: 是否有效, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let errorMsg = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(pointCount)个 ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(errorMsg)", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(errorMsg)", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败: \(errorMsg)", type: .error)
            return (false, errorMsg)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area  // 保存计算结果
        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(errorMsg)", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 全部验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }

    // MARK: - 综合检测方法（每10秒执行）

    /// 加载他人领地数据用于碰撞检测
    private func loadOthersTerritoriesForCollisionCheck() async {
        do {
            cachedOthersTerritories = try await TerritoryManager.shared.loadOthersTerritories()
            TerritoryLogger.shared.log("已加载 \(cachedOthersTerritories.count) 个他人领地用于综合检测", type: .info)
        } catch {
            print("⚠️ [综合检测] 加载他人领地失败: \(error)")
            TerritoryLogger.shared.log("加载他人领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 执行综合检测（轨迹穿越 + 点位置 + 距离预警）
    private func performComprehensiveCheck() async {
        // 如果没有在追踪或没有当前位置，跳过
        guard isTracking, let currentLoc = currentLocation else {
            return
        }

        // 如果还没有加载领地数据，跳过
        guard !cachedOthersTerritories.isEmpty else {
            return
        }

        let currentPoint = currentLoc.coordinate

        do {
            let result = try await TerritoryManager.shared.comprehensiveCheck(
                currentPoint: currentPoint,
                previousPoints: pathCoordinates,
                territories: cachedOthersTerritories
            )

            // 更新预警级别和距离
            currentWarningLevel = result.level
            distanceToNearestTerritory = result.distance

            // 根据结果采取行动
            switch result.level {
            case .violation:
                // 违规！立即停止追踪
                pathCollisionWarning = result.message
                TerritoryLogger.shared.log("违规！\(result.message)", type: .error)
                stopPathTracking()

            case .danger:
                // 危险区域，显示警告但继续追踪
                pathCollisionWarning = result.message
                TerritoryLogger.shared.log("危险区域：\(result.message)", type: .warning)

            case .caution:
                // 警告区域，显示提示
                pathCollisionWarning = result.message
                TerritoryLogger.shared.log("接近边界：\(result.message)", type: .warning)

            case .safe:
                // 安全，清除警告
                if pathCollisionWarning != nil {
                    pathCollisionWarning = nil
                }
            }

        } catch {
            print("⚠️ [综合检测] 检测失败: \(error)")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            // 更新授权状态
            authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // 用户授权后，开始定位
                locationError = nil
                startUpdatingLocation()

            case .denied:
                locationError = "您已拒绝定位权限，无法显示您的位置"
                stopUpdatingLocation()

            case .restricted:
                locationError = "定位服务受限，请检查设备设置"
                stopUpdatingLocation()

            case .notDetermined:
                // 尚未决定，等待用户选择
                break

            @unknown default:
                break
            }
        }
    }

    /// 位置更新回调
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新位置
        guard let location = locations.last else { return }

        Task { @MainActor in
            // 更新用户位置（供 UI 显示）
            userLocation = location.coordinate

            // 【关键】更新 currentLocation（供 Timer 采点使用）
            currentLocation = location

            // 传递位置更新给探索管理器
            ExplorationManager.shared.handleLocationUpdate(location)
        }
    }

    /// 定位失败回调
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // 处理定位错误
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = "定位权限被拒绝"
                case .locationUnknown:
                    locationError = "无法获取当前位置"
                case .network:
                    locationError = "网络错误，请检查网络连接"
                default:
                    locationError = "定位失败：\(error.localizedDescription)"
                }
            } else {
                locationError = "定位失败：\(error.localizedDescription)"
            }
        }
    }
}
