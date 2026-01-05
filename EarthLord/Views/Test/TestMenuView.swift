//
//  TestMenuView.swift
//  EarthLord
//
//  测试入口菜单 - 集中管理各种测试功能入口
//

import SwiftUI

// MARK: - TestMenuView

/// 测试模块入口页面
/// ⚠️ 不要套 NavigationStack，因为它已经在 MoreTabView 的 NavigationStack 内部
struct TestMenuView: View {

    var body: some View {
        List {
            Section {
                // Supabase 连接测试
                NavigationLink {
                    SupabaseTestView()
                } label: {
                    HStack(spacing: 12) {
                        // 图标
                        Image(systemName: "network")
                            .font(.system(size: 18))
                            .foregroundColor(ApocalypseTheme.info)
                            .frame(width: 32, height: 32)
                            .background(ApocalypseTheme.info.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // 标题和描述
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Supabase 连接测试")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("测试后端服务器连接")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 圈地功能测试
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    HStack(spacing: 12) {
                        // 图标
                        Image(systemName: "location.viewfinder")
                            .font(.system(size: 18))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32, height: 32)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // 标题和描述
                        VStack(alignment: .leading, spacing: 2) {
                            Text("圈地功能测试")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("查看圈地模块调试日志")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("调试工具")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .navigationTitle("开发测试")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
