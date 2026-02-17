//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器 - 使用 MapKit 搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

// MARK: - POI 搜索管理器

/// POI 搜索管理器
/// 使用 MapKit 的 MKLocalSearch 搜索附近的真实地点
class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    private init() {}

    // MARK: - Constants

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// POI 类型映射：MapKit 类别 -> 游戏内 POI 类型
    private let poiTypeMapping: [MKPointOfInterestCategory: POIType] = [
        .hospital: .hospital,
        .pharmacy: .pharmacy,
        .store: .supermarket,
        .gasStation: .gasStation,
        .foodMarket: .supermarket,
        .bakery: .supermarket
    ]

    // MARK: - Public Methods

    /// 搜索附近 1 公里内的 POI
    /// - Parameters:
    ///   - center: 搜索中心点坐标
    ///   - maxCount: 最大返回数量（根据玩家密度动态调整，默认不限制）
    /// - Returns: POI 列表（最多返回20个，因为地理围栏限制）
    func searchNearbyPOIs(
        center: CLLocationCoordinate2D,
        maxCount: Int = Int.max
    ) async throws -> [POI] {
        var allPOIs: [POI] = []

        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        // 搜索关键词（覆盖多种类型，确保有结果）
        let searchKeywords = ["超市", "便利店", "药店", "医院", "加油站", "商店", "餐厅", "咖啡"]

        // 并发搜索所有关键词
        await withTaskGroup(of: [POI].self) { group in
            for keyword in searchKeywords {
                group.addTask {
                    do {
                        return try await self.searchPOIs(keyword: keyword, region: region, center: center)
                    } catch {
                        print("⚠️ [POI搜索] 搜索 '\(keyword)' 失败: \(error)")
                        return []
                    }
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        // 去重（根据坐标）
        var uniquePOIs = removeDuplicates(pois: allPOIs)

        // 按距离排序
        uniquePOIs = sortByDistance(pois: uniquePOIs, from: center)

        // 根据密度限制数量（优先级1）
        // 然后限制最多20个（iOS地理围栏限制，优先级2）
        let densityLimit = min(maxCount, 20)
        if uniquePOIs.count > densityLimit {
            uniquePOIs = Array(uniquePOIs.prefix(densityLimit))
        }

        print("✅ [POI搜索] 共找到 \(uniquePOIs.count) 个 POI (密度限制: \(maxCount == Int.max ? "无" : "\(maxCount)"))")
        TerritoryLogger.shared.log("搜索到 \(uniquePOIs.count) 个附近地点", type: .success)

        return uniquePOIs
    }

    // MARK: - Private Methods

    /// 搜索指定关键词的 POI
    private func searchPOIs(keyword: String, region: MKCoordinateRegion, center: CLLocationCoordinate2D) async throws -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        // 转换为游戏内 POI 模型
        let pois = response.mapItems.compactMap { mapItem -> POI? in
            guard let location = mapItem.placemark.location else { return nil }

            // 检查是否在搜索半径内
            let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                .distance(from: location)
            guard distance <= searchRadius else { return nil }

            // 确定 POI 类型
            let poiType = determinePOIType(from: mapItem, keyword: keyword)

            // 生成危险等级
            let dangerLevel = generateDangerLevel(type: poiType)

            return POI(
                name: mapItem.name ?? "未知地点",
                type: poiType,
                coordinate: location.coordinate,
                status: .undiscovered,
                resourceStatus: .unknown,
                dangerLevel: dangerLevel,
                source: "地图数据",
                mapItem: mapItem
            )
        }

        print("📍 [POI搜索] '\(keyword)' 找到 \(pois.count) 个结果")

        return pois
    }

    /// 根据 MapItem 和搜索关键词确定 POI 类型
    private func determinePOIType(from mapItem: MKMapItem, keyword: String) -> POIType {
        // 优先使用 MapKit 的类别
        if let category = mapItem.pointOfInterestCategory,
           let poiType = poiTypeMapping[category] {
            return poiType
        }

        // 根据关键词推断
        let name = mapItem.name?.lowercased() ?? ""
        let keywordLower = keyword.lowercased()

        if keywordLower.contains("医院") || name.contains("医院") || name.contains("hospital") {
            return .hospital
        } else if keywordLower.contains("药") || name.contains("药") || name.contains("pharmacy") {
            return .pharmacy
        } else if keywordLower.contains("加油") || name.contains("加油") || name.contains("gas") {
            return .gasStation
        } else if keywordLower.contains("超市") || keywordLower.contains("便利") || keywordLower.contains("商店") ||
                    name.contains("超市") || name.contains("便利") || name.contains("市场") {
            return .supermarket
        }

        // 默认类型
        return .supermarket
    }

    /// 生成危险等级（支持 5 级：安全/低危/中危/高危/极危）
    private func generateDangerLevel(type: POIType) -> DangerLevel {
        var baseDanger: Int
        switch type {
        case .hospital:
            baseDanger = 2    // 医院中危起步
        case .factory:
            baseDanger = 3    // 工厂高危起步
        case .gasStation:
            baseDanger = 1    // 加油站低危起步
        case .pharmacy:
            baseDanger = 1    // 药店低危起步
        case .supermarket:
            baseDanger = 0    // 超市安全起步
        }

        // 随机增加 0-2 级危险
        let randomFactor = Int.random(in: 0...2)
        let totalDanger = min(baseDanger + randomFactor, 4)  // 最高 4（极危）

        return DangerLevel(rawValue: totalDanger) ?? .safe
    }

    /// 去除重复 POI（距离小于 50 米视为同一地点）
    private func removeDuplicates(pois: [POI]) -> [POI] {
        var uniquePOIs: [POI] = []

        for poi in pois {
            let isDuplicate = uniquePOIs.contains { existingPOI in
                let distance = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
                    .distance(from: CLLocation(latitude: existingPOI.coordinate.latitude, longitude: existingPOI.coordinate.longitude))
                return distance < 50
            }

            if !isDuplicate {
                uniquePOIs.append(poi)
            }
        }

        return uniquePOIs
    }

    /// 按距离排序
    private func sortByDistance(pois: [POI], from center: CLLocationCoordinate2D) -> [POI] {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return pois.sorted { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return centerLocation.distance(from: loc1) < centerLocation.distance(from: loc2)
        }
    }
}
