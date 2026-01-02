//
//  SettingsView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

/// 设置页面
struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    // 删除账户相关状态
    @State private var showDeleteAccountAlert = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    // 语言选择
    @State private var showLanguagePicker = false

    /// 需要输入的确认文字
    private let requiredConfirmText = "删除"

    var body: some View {
        List {
            // 账户设置
            Section {
                // 修改密码（预留）
                HStack {
                    Label("修改密码", systemImage: "key.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .listRowBackground(ApocalypseTheme.cardBackground)

                // 隐私设置（预留）
                HStack {
                    Label("隐私设置", systemImage: "hand.raised.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .listRowBackground(ApocalypseTheme.cardBackground)
            } header: {
                Text("账户设置")
            }

            // 通用设置
            Section {
                // 通知设置（预留）
                HStack {
                    Label("通知设置", systemImage: "bell.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .listRowBackground(ApocalypseTheme.cardBackground)

                // 语言设置
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack {
                        Label("语言", systemImage: "globe")
                        Spacer()
                        Text(languageManager.currentLanguage.displayName)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .listRowBackground(ApocalypseTheme.cardBackground)
            } header: {
                Text("通用")
            }

            // 关于
            Section {
                HStack {
                    Label("版本", systemImage: "info.circle.fill")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .listRowBackground(ApocalypseTheme.cardBackground)
            } header: {
                Text("关于")
            }

            // 危险区域
            Section {
                Button {
                    print("[SettingsView] 用户点击删除账户按钮")
                    showDeleteAccountAlert = true
                } label: {
                    HStack {
                        Label("删除账户", systemImage: "trash.fill")
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .foregroundColor(ApocalypseTheme.danger)
                .disabled(isDeleting)
                .listRowBackground(ApocalypseTheme.cardBackground)
            } header: {
                Text("危险区域")
            } footer: {
                Text("删除账户后，您的所有数据将被永久删除且无法恢复。")
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        // 删除账户确认对话框
        .alert("删除账户", isPresented: $showDeleteAccountAlert) {
            TextField("请输入「\(requiredConfirmText)」确认", text: $deleteConfirmText)
            Button("取消", role: .cancel) {
                print("[SettingsView] 用户取消删除账户")
                deleteConfirmText = ""
            }
            Button("确认删除", role: .destructive) {
                print("[SettingsView] 用户确认删除账户，输入内容: \(deleteConfirmText)")
                if deleteConfirmText == requiredConfirmText {
                    performDeleteAccount()
                } else {
                    print("[SettingsView] 确认文字不匹配")
                    deleteErrorMessage = "请输入正确的确认文字"
                    showDeleteError = true
                }
                deleteConfirmText = ""
            }
            .disabled(deleteConfirmText != requiredConfirmText)
        } message: {
            Text("此操作不可撤销！您的所有数据将被永久删除。\n\n请输入「\(requiredConfirmText)」以确认删除账户。")
        }
        // 删除错误提示
        .alert("删除失败", isPresented: $showDeleteError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
        // 语言选择器
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(languageManager: languageManager)
        }
    }

    // MARK: - 删除账户

    private func performDeleteAccount() {
        print("[SettingsView] 开始执行删除账户...")
        isDeleting = true

        Task {
            let success = await authManager.deleteAccount()

            await MainActor.run {
                isDeleting = false

                if success {
                    print("[SettingsView] 账户删除成功，将自动跳转到登录页")
                    // 删除成功，AuthManager 会自动重置状态
                    // EarthLordApp 会监听 isAuthenticated 变化并跳转到登录页
                } else {
                    print("[SettingsView] 账户删除失败")
                    deleteErrorMessage = authManager.errorMessage ?? "删除账户失败，请稍后重试"
                    showDeleteError = true
                }
            }
        }
    }
}

// MARK: - 语言选择器视图
struct LanguagePickerView: View {
    @ObservedObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageManager.setLanguage(language)
                        dismiss()
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ApocalypseTheme.background)
            .navigationTitle("选择语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
