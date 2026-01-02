//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 负责获取和管理用户位置
//

import Foundation
import CoreLocation
import Combine  // @Published 需要这个框架
import UIKit    // UIApplication 需要这个框架

// MARK: - LocationManager

/// GPS 定位管理器
/// 负责请求定位权限、获取用户位置、处理授权状态变化
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

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
            // 更新用户位置
            userLocation = location.coordinate
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
