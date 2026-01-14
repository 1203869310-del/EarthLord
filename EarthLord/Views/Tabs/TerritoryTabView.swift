//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面 - 显示我的领地列表和统计信息
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - State

    @StateObject private var territoryManager = TerritoryManager.shared

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 选中的领地（用于显示详情）
    @State private var selectedTerritory: Territory?

    /// 错误信息
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 加载中
                    ProgressView("加载中...")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                await loadMyTerritories()
            }
        }
        .onAppear {
            Task {
                await loadMyTerritories()
            }
        }
        .sheet(item: $selectedTerritory) { territory in
            TerritoryDetailView(
                territory: territory,
                onDelete: {
                    // 删除后刷新列表
                    Task {
                        await loadMyTerritories()
                    }
                }
            )
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("去地图页面圈一块属于你的领地吧！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Territory List View

    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计卡片
                statsCard

                // 领地列表
                ForEach(myTerritories) { territory in
                    TerritoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 20) {
            // 领地数量
            VStack(spacing: 4) {
                Text("\(myTerritories.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("领地数量")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textSecondary.opacity(0.3))
                .frame(width: 1, height: 50)

            // 总面积
            VStack(spacing: 4) {
                Text(formattedTotalArea)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("总面积")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Methods

    private func loadMyTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Territory Card

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    Label(territory.formattedArea, systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let pointCount = territory.pointCount {
                        Label("\(pointCount) 点", systemImage: "mappin.circle")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Text(territory.formattedDate)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
