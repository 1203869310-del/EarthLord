//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器，负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 领地管理器
@MainActor
final class TerritoryManager: ObservableObject {

    // MARK: - 单例
    static let shared = TerritoryManager()

    // MARK: - 发布属性
    @Published private(set) var territories: [Territory] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - 私有属性
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...] 格式的数组
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 字符串，如 "SRID=4326;POLYGON((lon lat, ...))"
    ///
    /// 注意：WKT 格式是「经度在前，纬度在后」！
    /// 多边形必须闭合（首尾坐标相同）
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return ""
        }

        var coords = coordinates

        // 确保多边形闭合（首尾相同）
        if let first = coords.first, let last = coords.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                coords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointStrings = coords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        let polygonString = pointStrings.joined(separator: ", ")
        return "SRID=4326;POLYGON((\(polygonString)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传领地

    /// 上传领地到数据库
    /// - Parameters:
    ///   - coordinates: 领地边界坐标
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TerritoryError.notAuthenticated
        }

        guard coordinates.count >= 3 else {
            throw TerritoryError.invalidCoordinates
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // 准备数据
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)

        guard let bbox = calculateBoundingBox(coordinates) else {
            throw TerritoryError.invalidCoordinates
        }

        // 构建上传数据
        let territoryData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "path": .array(pathJSON.map { dict in
                .object(dict.mapValues { .double($0) })
            }),
            "polygon": .string(wktPolygon),
            "bbox_min_lat": .double(bbox.minLat),
            "bbox_max_lat": .double(bbox.maxLat),
            "bbox_min_lon": .double(bbox.minLon),
            "bbox_max_lon": .double(bbox.maxLon),
            "area": .double(area),
            "point_count": .integer(coordinates.count),
            "started_at": .string(startTime.ISO8601Format()),
            "completed_at": .string(Date().ISO8601Format()),
            "is_active": .bool(true)
        ]

        print("[TerritoryManager] 开始上传领地...")
        print("[TerritoryManager] 用户ID: \(userId)")
        print("[TerritoryManager] 坐标点数: \(coordinates.count)")
        print("[TerritoryManager] 面积: \(area) 平方米")

        // 【日志】记录开始上传
        TerritoryLogger.shared.log("开始上传领地，面积: \(Int(area))m²", type: .info)

        do {
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("[TerritoryManager] 领地上传成功!")

            // 【日志】记录上传成功
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            print("[TerritoryManager] 上传失败: \(error)")
            errorMessage = "上传失败: \(error.localizedDescription)"

            // 【日志】记录上传失败
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - 加载领地

    /// 加载所有激活的领地
    /// - Returns: 领地数组
    func loadAllTerritories() async throws -> [Territory] {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        print("[TerritoryManager] 开始加载领地...")

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            territories = response
            print("[TerritoryManager] 加载成功，共 \(response.count) 个领地")
            return response
        } catch {
            print("[TerritoryManager] 加载失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 加载当前用户的领地
    /// - Returns: 当前用户的领地数组
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TerritoryError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        print("[TerritoryManager] 加载用户领地: \(userId)")

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            print("[TerritoryManager] 加载成功，共 \(response.count) 个领地")
            return response
        } catch {
            print("[TerritoryManager] 加载失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - 删除领地

    /// 删除指定领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteTerritory(territoryId: String) async -> Bool {
        print("[TerritoryManager] 开始删除领地: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("[TerritoryManager] 领地删除成功")
            TerritoryLogger.shared.log("领地删除成功", type: .success)
            return true
        } catch {
            print("[TerritoryManager] 删除失败: \(error)")
            TerritoryLogger.shared.log("领地删除失败: \(error.localizedDescription)", type: .error)
            errorMessage = "删除失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 碰撞检测

    /// 加载他人的领地（排除当前用户）
    /// - Returns: 他人的领地数组
    func loadOthersTerritories() async throws -> [Territory] {
        guard let userId = AuthManager.shared.currentUserId else {
            throw TerritoryError.notAuthenticated
        }

        print("[TerritoryManager] 加载他人领地，排除用户: \(userId)")

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .neq("user_id", value: userId.uuidString)
                .execute()
                .value

            print("[TerritoryManager] 加载成功，共 \(response.count) 个他人领地")
            return response
        } catch {
            print("[TerritoryManager] 加载他人领地失败: \(error)")
            throw error
        }
    }

    /// 判断两条线段是否相交（CCW 算法）
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
        func ccw(_ A: CLLocationCoordinate2D,
                 _ B: CLLocationCoordinate2D,
                 _ C: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 判断点是否在多边形内（射线法）
    /// - Parameters:
    ///   - point: 测试点
    ///   - polygon: 多边形坐标数组
    /// - Returns: true 表示点在多边形内
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var isInside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            // 射线法：从点向右发射射线，计算与多边形边的交点
            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                isInside.toggle()
            }

            j = i
        }

        return isInside
    }

    /// 检测起始点是否与他人领地碰撞
    /// - Parameter startPoint: 起始点坐标
    /// - Returns: 碰撞的领地（如果有）
    func checkStartPointCollision(startPoint: CLLocationCoordinate2D) async throws -> Territory? {
        let othersTerritories = try await loadOthersTerritories()

        TerritoryLogger.shared.log("检测起始点碰撞，共 \(othersTerritories.count) 个他人领地", type: .info)

        for territory in othersTerritories {
            // 先用边界框快速过滤（如果有bbox数据）
            if let bboxMinLat = territory.bboxMinLat,
               let bboxMaxLat = territory.bboxMaxLat,
               let bboxMinLon = territory.bboxMinLon,
               let bboxMaxLon = territory.bboxMaxLon {

                // 检查点是否在边界框内
                let inBBox = startPoint.latitude >= bboxMinLat &&
                            startPoint.latitude <= bboxMaxLat &&
                            startPoint.longitude >= bboxMinLon &&
                            startPoint.longitude <= bboxMaxLon

                // 不在边界框内，跳过此领地
                if !inBBox {
                    continue
                }
            }

            // 边界框内（或没有bbox数据），用精确算法判断
            let coordinates = territory.toCoordinates()
            if isPointInPolygon(point: startPoint, polygon: coordinates) {
                TerritoryLogger.shared.log("起始点在他人领地内！领地ID: \(territory.id)", type: .error)
                return territory
            }
        }

        TerritoryLogger.shared.log("起始点安全，未碰撞 ✓", type: .success)
        return nil
    }

    /// 检测线段是否与他人领地边界相交
    /// - Parameters:
    ///   - segmentStart: 线段起点
    ///   - segmentEnd: 线段终点
    ///   - territories: 领地列表（可选，如果为 nil 则自动加载）
    /// - Returns: 相交的领地（如果有）
    func checkSegmentCollision(segmentStart: CLLocationCoordinate2D,
                              segmentEnd: CLLocationCoordinate2D,
                              territories: [Territory]? = nil) async throws -> Territory? {
        // 获取或加载领地数据
        let othersTerritories: [Territory]
        if let cached = territories {
            othersTerritories = cached
        } else {
            othersTerritories = try await loadOthersTerritories()
        }

        for territory in othersTerritories {
            let coordinates = territory.toCoordinates()
            guard coordinates.count >= 2 else { continue }

            // 检查线段是否与领地的任何边界相交
            for i in 0..<coordinates.count {
                let boundaryStart = coordinates[i]
                let boundaryEnd = coordinates[(i + 1) % coordinates.count]  // 循环到首点

                if segmentsIntersect(p1: segmentStart, p2: segmentEnd,
                                   p3: boundaryStart, p4: boundaryEnd) {
                    TerritoryLogger.shared.log("路径与他人领地相交！领地ID: \(territory.id)", type: .error)
                    return territory
                }
            }
        }

        return nil
    }

    // MARK: - 三合一综合检测

    /// 计算点到线段的最短距离
    /// - Parameters:
    ///   - point: 测试点
    ///   - lineStart: 线段起点
    ///   - lineEnd: 线段终点
    /// - Returns: 最短距离（米）
    private func distanceFromPointToSegment(point: CLLocationCoordinate2D,
                                           lineStart: CLLocationCoordinate2D,
                                           lineEnd: CLLocationCoordinate2D) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let endLoc = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        // 向量计算
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        if dx == 0 && dy == 0 {
            // 线段退化为点
            return pointLoc.distance(from: startLoc)
        }

        // 参数 t 表示点在线段上的投影位置
        let t = ((point.longitude - lineStart.longitude) * dx +
                (point.latitude - lineStart.latitude) * dy) / (dx * dx + dy * dy)

        if t < 0 {
            // 投影在起点之前，返回到起点的距离
            return pointLoc.distance(from: startLoc)
        } else if t > 1 {
            // 投影在终点之后，返回到终点的距离
            return pointLoc.distance(from: endLoc)
        } else {
            // 投影在线段上
            let projLat = lineStart.latitude + t * dy
            let projLon = lineStart.longitude + t * dx
            let projLoc = CLLocation(latitude: projLat, longitude: projLon)
            return pointLoc.distance(from: projLoc)
        }
    }

    /// 计算点到多边形边界的最短距离
    /// - Parameters:
    ///   - point: 测试点
    ///   - polygon: 多边形坐标数组
    /// - Returns: 最短距离（米）
    private func distanceToPolygonBoundary(point: CLLocationCoordinate2D,
                                          polygon: [CLLocationCoordinate2D]) -> Double {
        guard polygon.count >= 2 else { return Double.infinity }

        var minDistance = Double.infinity

        for i in 0..<polygon.count {
            let segmentStart = polygon[i]
            let segmentEnd = polygon[(i + 1) % polygon.count]

            let distance = distanceFromPointToSegment(
                point: point,
                lineStart: segmentStart,
                lineEnd: segmentEnd
            )

            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    /// 综合检测：轨迹穿越 + 点位置 + 距离预警
    /// - Parameters:
    ///   - currentPoint: 当前位置
    ///   - previousPoints: 之前的路径点（用于检测轨迹穿越）
    ///   - territories: 领地列表（可选）
    /// - Returns: 检测结果
    func comprehensiveCheck(currentPoint: CLLocationCoordinate2D,
                           previousPoints: [CLLocationCoordinate2D],
                           territories: [Territory]? = nil) async throws -> TerritoryCheckResult {
        // 获取或加载领地数据
        let othersTerritories: [Territory]
        if let cached = territories {
            othersTerritories = cached
        } else {
            othersTerritories = try await loadOthersTerritories()
        }

        guard !othersTerritories.isEmpty else {
            return TerritoryCheckResult(
                level: .safe,
                distance: nil,
                message: "附近无他人领地",
                violatedTerritory: nil
            )
        }

        var minDistance = Double.infinity
        var closestTerritory: Territory?

        for territory in othersTerritories {
            let coordinates = territory.toCoordinates()
            guard coordinates.count >= 2 else { continue }

            // 1. 检测轨迹穿越（如果有之前的点）
            if previousPoints.count >= 2 {
                let lastSegmentStart = previousPoints[previousPoints.count - 2]
                let lastSegmentEnd = previousPoints[previousPoints.count - 1]

                for i in 0..<coordinates.count {
                    let boundaryStart = coordinates[i]
                    let boundaryEnd = coordinates[(i + 1) % coordinates.count]

                    if segmentsIntersect(p1: lastSegmentStart, p2: lastSegmentEnd,
                                       p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("轨迹穿越检测：已穿过领地 \(territory.id)", type: .error)
                        return TerritoryCheckResult(
                            level: .violation,
                            distance: 0,
                            message: "轨迹穿越他人领地边界",
                            violatedTerritory: territory
                        )
                    }
                }
            }

            // 2. 检测点位置（当前点是否在领地内）
            if isPointInPolygon(point: currentPoint, polygon: coordinates) {
                TerritoryLogger.shared.log("点位置检测：当前位置在领地 \(territory.id) 内", type: .error)
                return TerritoryCheckResult(
                    level: .violation,
                    distance: 0,
                    message: "当前位置在他人领地内",
                    violatedTerritory: territory
                )
            }

            // 3. 计算距离
            let distance = distanceToPolygonBoundary(point: currentPoint, polygon: coordinates)
            if distance < minDistance {
                minDistance = distance
                closestTerritory = territory
            }
        }

        // 根据距离确定预警级别
        let level: TerritoryWarningLevel
        let message: String

        if minDistance > 50 {
            level = .safe
            message = "安全距离：\(String(format: "%.0f", minDistance))m"
        } else if minDistance > 20 {
            level = .caution
            message = "接近边界：\(String(format: "%.0f", minDistance))m"
        } else {
            level = .danger
            message = "危险区域：\(String(format: "%.0f", minDistance))m"
        }

        TerritoryLogger.shared.log("综合检测：\(level.displayName)，距离 \(String(format: "%.0f", minDistance))m", type: .info)

        return TerritoryCheckResult(
            level: level,
            distance: minDistance,
            message: message,
            violatedTerritory: closestTerritory
        )
    }
}

// MARK: - 预警级别
enum TerritoryWarningLevel: String {
    case safe = "safe"           // 安全（> 50m）
    case caution = "caution"     // 警告（20-50m）
    case danger = "danger"       // 危险（< 20m）
    case violation = "violation" // 违规（已穿越或在领地内）

    var displayName: String {
        switch self {
        case .safe:
            return "安全"
        case .caution:
            return "接近边界"
        case .danger:
            return "危险区域"
        case .violation:
            return "违规"
        }
    }

    var color: String {
        switch self {
        case .safe:
            return "green"
        case .caution:
            return "yellow"
        case .danger:
            return "orange"
        case .violation:
            return "red"
        }
    }
}

// MARK: - 检测结果
struct TerritoryCheckResult {
    let level: TerritoryWarningLevel
    let distance: Double?          // 距离最近领地的距离（米）
    let message: String
    let violatedTerritory: Territory?  // 违规的领地

    var isViolation: Bool {
        level == .violation
    }
}

// MARK: - 错误类型
enum TerritoryError: LocalizedError {
    case notAuthenticated
    case invalidCoordinates
    case uploadFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .invalidCoordinates:
            return "无效的坐标数据"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        }

    }
}
