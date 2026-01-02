//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图和用户位置
//

import SwiftUI
import MapKit

// MARK: - MapTabView

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 用户位置（从地图回传）
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 底层：末世风格地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser
            )
            .ignoresSafeArea()

            // 顶层：UI 覆盖层
            VStack {
                // 顶部状态栏
                topStatusBar

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

    /// 底部控制栏：定位按钮等
    private var bottomControlBar: some View {
        HStack {
            Spacer()

            // 定位按钮
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
            .padding(.trailing, 16)
            .padding(.bottom, 30)
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
}
