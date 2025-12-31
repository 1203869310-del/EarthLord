//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

struct ProfileTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头像和用户信息
                    profileHeader

                    // 统计数据
                    statsSection

                    // 菜单列表
                    menuSection

                    // 登出按钮
                    logoutButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("确认登出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("登出", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
    }

    // MARK: - 头像和用户信息
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text(avatarText)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

            // 用户名/邮箱
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(authManager.currentUserEmail ?? "未知邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 用户ID
            if let userId = authManager.currentUserId {
                Text("ID: \(userId.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - 统计数据
    private var statsSection: some View {
        HStack(spacing: 0) {
            StatItem(value: "0", label: "领地")
            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted.opacity(0.3))
            StatItem(value: "0", label: "资源点")
            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted.opacity(0.3))
            StatItem(value: "0㎡", label: "总面积")
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 菜单列表
    private var menuSection: some View {
        VStack(spacing: 0) {
            ProfileMenuItem(icon: "person.text.rectangle", title: "编辑资料", color: ApocalypseTheme.info) {
                // TODO: 编辑资料
            }

            Divider().background(ApocalypseTheme.textMuted.opacity(0.2))

            ProfileMenuItem(icon: "bell.fill", title: "消息通知", color: ApocalypseTheme.warning) {
                // TODO: 消息通知
            }

            Divider().background(ApocalypseTheme.textMuted.opacity(0.2))

            ProfileMenuItem(icon: "gearshape.fill", title: "设置", color: ApocalypseTheme.textSecondary) {
                // TODO: 设置
            }

            Divider().background(ApocalypseTheme.textMuted.opacity(0.2))

            ProfileMenuItem(icon: "questionmark.circle.fill", title: "帮助与反馈", color: ApocalypseTheme.success) {
                // TODO: 帮助
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 登出按钮
    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
        .padding(.top, 10)
    }

    // MARK: - 辅助属性
    private var avatarText: String {
        if let email = authManager.currentUserEmail, let first = email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var displayName: String {
        if let email = authManager.currentUserEmail {
            return email.components(separatedBy: "@").first ?? "用户"
        }
        return "用户"
    }
}

// MARK: - 统计项组件
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 菜单项组件
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(title)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding()
        }
    }
}

#Preview {
    ProfileTabView()
}
