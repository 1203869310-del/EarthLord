//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具 - WGS-84 与 GCJ-02 坐标系互转
//  解决中国地区 GPS 偏移问题
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter

/// 坐标转换工具
/// 用于 WGS-84（GPS 原始坐标）与 GCJ-02（中国火星坐标）之间的转换
enum CoordinateConverter {

    // MARK: - Constants

    /// 地球长半轴（米）
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = Double.pi

    // MARK: - Public Methods

    /// WGS-84 转 GCJ-02
    /// - Parameter wgs84: GPS 原始坐标（WGS-84）
    /// - Returns: 中国火星坐标（GCJ-02）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，直接返回原坐标（无需转换）
        if isOutOfChina(wgs84) {
            return wgs84
        }

        // 计算偏移量
        var dLat = transformLat(wgs84.longitude - 105.0, wgs84.latitude - 35.0)
        var dLon = transformLon(wgs84.longitude - 105.0, wgs84.latitude - 35.0)

        let radLat = wgs84.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let gcj02Lat = wgs84.latitude + dLat
        let gcj02Lon = wgs84.longitude + dLon

        return CLLocationCoordinate2D(latitude: gcj02Lat, longitude: gcj02Lon)
    }

    /// GCJ-02 转 WGS-84（逆向转换，精度略低）
    /// - Parameter gcj02: 中国火星坐标（GCJ-02）
    /// - Returns: GPS 原始坐标（WGS-84）
    static func gcj02ToWgs84(_ gcj02: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，直接返回原坐标
        if isOutOfChina(gcj02) {
            return gcj02
        }

        // 使用迭代法提高精度
        let transformed = wgs84ToGcj02(gcj02)
        let dLat = transformed.latitude - gcj02.latitude
        let dLon = transformed.longitude - gcj02.longitude

        return CLLocationCoordinate2D(
            latitude: gcj02.latitude - dLat,
            longitude: gcj02.longitude - dLon
        )
    }

    /// 批量转换坐标数组（WGS-84 → GCJ-02）
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func convertPath(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国范围外
    private static func isOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 中国大致范围：经度 73.66 ~ 135.05，纬度 3.86 ~ 53.55
        if coordinate.longitude < 72.004 || coordinate.longitude > 137.8347 {
            return true
        }
        if coordinate.latitude < 0.8293 || coordinate.latitude > 55.8271 {
            return true
        }
        return false
    }

    /// 转换纬度偏移
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 转换经度偏移
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
