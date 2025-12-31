//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// 认证管理器 - 全局状态
    @StateObject private var authManager = AuthManager.shared

    /// 应用状态
    @State private var appState: AppState = .splash

    /// 应用状态枚举
    enum AppState {
        case splash      // 启动画面
        case auth        // 认证页面（未登录）
        case main        // 主界面（已登录）
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState {
                case .splash:
                    // 启动画面
                    SplashView { isAuthenticated in
                        // 启动完成回调
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState = isAuthenticated ? .main : .auth
                        }
                    }
                    .transition(.opacity)

                case .auth:
                    // 认证页面
                    AuthView()
                        .transition(.opacity)
                        .environmentObject(authManager)

                case .main:
                    // 主界面
                    MainTabView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState)
            // 监听认证状态变化
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                // 只在非启动状态下响应认证变化
                if appState != .splash {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState = isAuthenticated ? .main : .auth
                    }
                }
            }
            // 监听是否需要设置密码（注册流程中）
            .onChange(of: authManager.needsPasswordSetup) { _, needsSetup in
                // 如果在主界面但需要设置密码，跳转到认证页面
                if needsSetup && appState == .main {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState = .auth
                    }
                }
            }
        }
    }
}

// MARK: - AppState Equatable
extension EarthLordApp.AppState: Equatable {}
