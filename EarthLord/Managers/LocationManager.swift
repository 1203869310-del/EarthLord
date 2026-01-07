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

    // MARK: - Private Properties

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
        locationManager.distanceFilter = 10  // 移动10米才更新位置
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

        // 确保定位正在运行
        startUpdatingLocation()

        // 立即记录第一个点（如果有位置的话）
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 [路径追踪] 记录起始点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        // 启动定时器，每 2 秒采点一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordPathPoint()
            }
        }

        print("🚀 [路径追踪] 开始追踪，定时器间隔: \(trackingInterval)秒")

        // 【日志】记录开始追踪
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 更新状态
        isTracking = false

        // 重置速度检测状态
        lastLocation = nil
        lastLocationTimestamp = nil

        print("🛑 [路径追踪] 停止追踪，共记录 \(pathCoordinates.count) 个点")

        // 【日志】记录停止追踪
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)
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

    // MARK: - 速度检测方法

    /// 验证移动速度是否正常
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常可以记录，false 表示超速需要跳过
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        let now = Date()

        // 如果是第一个点，记录位置和时间，直接通过
        guard let prevLocation = lastLocation, let prevTimestamp = lastLocationTimestamp else {
            lastLocation = newLocation
            lastLocationTimestamp = now
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: prevLocation)

        // 计算时间差（秒）
        let timeDelta = now.timeIntervalSince(prevTimestamp)

        // 防止除零错误
        guard timeDelta > 0 else {
            return true
        }

        // 计算速度（km/h）= 距离(m) ÷ 时间(s) × 3.6
        let speedKmh = (distance / timeDelta) * 3.6

        // 更新上次位置和时间戳
        lastLocation = newLocation
        lastLocationTimestamp = now

        print("🚗 [速度检测] 速度: \(String(format: "%.1f", speedKmh)) km/h")

        // 速度 > 50 km/h，自动停止追踪（可能坐车或 GPS 跳变）
        if speedKmh > 50 {
            speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），追踪已暂停"
            isOverSpeed = true
            print("🚨 [速度检测] 速度 > 50 km/h，自动停止追踪！")

            // 【日志】记录超速停止（先记录日志再停止，否则会先记录停止日志）
            TerritoryLogger.shared.log("超速 \(String(format: "%.0f", speedKmh)) km/h，已停止追踪", type: .error)

            stopPathTracking()
            return false
        }

        // 速度 > 25 km/h，显示警告但继续追踪（排除正常走路的 GPS 抖动）
        if speedKmh > 25 {
            speedWarning = "移动速度较快（\(String(format: "%.0f", speedKmh)) km/h）"
            isOverSpeed = true
            print("⚠️ [速度检测] 速度 > 25 km/h，显示警告")

            // 【日志】记录速度警告
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.0f", speedKmh)) km/h", type: .warning)
            return true
        }

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

    /// 检测路径是否存在自相交
    /// - Returns: true 表示存在自相交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判为自交）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

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

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
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
