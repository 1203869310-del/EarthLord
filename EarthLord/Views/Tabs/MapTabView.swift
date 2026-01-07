//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置和圈地功能
//

import SwiftUI
import MapKit

// MARK: - MapTabView

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器（使用 EnvironmentObject 与其他页面共享）
    @EnvironmentObject var locationManager: LocationManager

    /// 用户位置（从地图回传）
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 底层：末世风格地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed
            )
            .ignoresSafeArea()

            // 顶层：UI 覆盖层
            VStack {
                // 顶部状态栏
                topStatusBar

                // 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                }

                Spacer()

                // 底部控制栏
                bottomControlBar
            }

            // 权限被拒绝时显示提示卡片
            if locationManager.isDenied {
                permissionDeniedCard
            }
        }
        .onAppear {
            // 页面出现时请求定位权限
            if locationManager.isNotDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Top Status Bar

    /// 顶部状态栏：显示坐标信息
    private var topStatusBar: some View {
        HStack {
            // 位置图标
            Image(systemName: "location.fill")
                .foregroundColor(ApocalypseTheme.primary)
                .font(.system(size: 14))

            // 坐标文字
            if let location = userLocation {
                Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                Text("定位中...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 末世日期标签（装饰）
            Text("Day 1")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.warning.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    ApocalypseTheme.cardBackground.opacity(0.95),
                    ApocalypseTheme.cardBackground.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Bottom Control Bar

    /// 底部控制栏：定位按钮 + 圈地按钮
    private var bottomControlBar: some View {
        HStack(alignment: .bottom) {
            Spacer()

            VStack(spacing: 12) {
                // 定位按钮
                locationButton

                // 圈地按钮
                trackingButton
            }
            .padding(.trailing, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Location Button

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            // 重新请求定位或居中到用户位置
            if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
                // 重置居中标志，下次位置更新时会自动居中
                hasLocatedUser = false
            } else if locationManager.isDenied {
                // 打开设置
                locationManager.openSettings()
            } else {
                locationManager.requestPermission()
            }
        }) {
            ZStack {
                // 背景圆
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 定位图标
                Image(systemName: locationIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(locationIconColor)
            }
        }
    }

    /// 定位按钮图标
    private var locationIcon: String {
        if locationManager.isDenied {
            return "location.slash.fill"
        } else if hasLocatedUser {
            return "location.fill"
        } else {
            return "location"
        }
    }

    /// 定位按钮颜色
    private var locationIconColor: Color {
        if locationManager.isDenied {
            return ApocalypseTheme.danger
        } else if hasLocatedUser {
            return ApocalypseTheme.primary
        } else {
            return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - Tracking Button

    /// 圈地按钮
    private var trackingButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止追踪
                locationManager.stopPathTracking()
            } else {
                // 开始追踪
                locationManager.startPathTracking()
            }
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 14, weight: .semibold))

                // 文字
                if locationManager.isTracking {
                    Text("停止圈地")
                        .font(.system(size: 14, weight: .semibold))

                    // 显示当前点数
                    Text("\(locationManager.pathPointCount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Text("开始圈地")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        // 未授权时禁用按钮
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

    // MARK: - Speed Warning Banner

    /// 速度警告横幅
    private var speedWarningBanner: some View {
        HStack {
            // 警告图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))

            // 警告文字
            Text(locationManager.speedWarning ?? "")
                .font(.system(size: 14, weight: .medium))

            Spacer()

            // 关闭按钮
            Button(action: {
                locationManager.speedWarning = nil
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            // 根据追踪状态选择背景色
            // 还在追踪：黄色警告；已停止：红色错误
            locationManager.isTracking ?
                ApocalypseTheme.warning :
                ApocalypseTheme.danger
        )
        .onAppear {
            // 3 秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                locationManager.speedWarning = nil
            }
        }
    }

    // MARK: - Validation Result Banner

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
    }

    // MARK: - Permission Denied Card

    /// 权限被拒绝时的提示卡片
    private var permissionDeniedCard: some View {
        VStack(spacing: 16) {
            // 警告图标
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text("无法获取位置")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("您已拒绝定位权限，无法在地图上显示您的位置。请在设置中开启定位权限。")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 前往设置按钮
            Button(action: {
                locationManager.openSettings()
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("前往设置")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 32)
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
