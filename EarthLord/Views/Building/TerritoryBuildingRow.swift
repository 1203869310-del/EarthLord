//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑列表行 + 圆形进度视图

import SwiftUI
import Combine

// MARK: - CircularProgressView

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - TerritoryBuildingRow

struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onUpgrade: () -> Void
    let onDemolish: () -> Void

    @State private var timerTick = 0

    private var categoryEmoji: String {
        switch template?.category {
        case .survival:   return "🏕"
        case .storage:    return "📦"
        case .production: return "⚙️"
        case .energy:     return "⚡️"
        case nil:         return "🏗"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左：分类圆圈图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(categoryEmoji)
                    .font(.system(size: 20))
            }

            // 中：建筑信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(building.buildingName) Lv.\(building.level)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 状态徽章
                    Text(building.status.displayName)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(building.status.color)
                        .clipShape(Capsule())
                }

                if building.status == .constructing {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: building.buildProgress)
                            .accentColor(.orange)
                            .frame(maxWidth: 160)
                        Text(building.formattedRemainingTime)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // 右：操作区
            if building.status == .active {
                Menu {
                    if let tmpl = template, building.level < tmpl.maxLevel {
                        Button {
                            onUpgrade()
                        } label: {
                            Label("升级", systemImage: "arrow.up.circle")
                        }
                    }
                    Button(role: .destructive) {
                        onDemolish()
                    } label: {
                        Label("拆除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } else {
                CircularProgressView(progress: building.buildProgress)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.vertical, 4)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            timerTick += 1  // 触发视图刷新，更新倒计时
        }
    }
}
