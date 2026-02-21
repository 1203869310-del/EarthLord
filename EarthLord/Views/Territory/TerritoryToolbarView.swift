//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  领地详情顶部工具栏

import SwiftUI

struct TerritoryToolbarView: View {
    let territoryName: String
    let onDismiss: () -> Void
    let onBuildingBrowser: () -> Void
    @Binding var showInfoPanel: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 2)
            }

            // 领地名
            Text(territoryName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .shadow(radius: 2)

            Spacer()

            // 建造按钮
            Button(action: onBuildingBrowser) {
                Label("建造", systemImage: "hammer.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.primary)
                    .clipShape(Capsule())
                    .shadow(radius: 2)
            }

            // 信息面板切换
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showInfoPanel.toggle()
                }
            } label: {
                Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.top, 8)
        .background(
            ApocalypseTheme.cardBackground.opacity(0.85)
                .background(.ultraThinMaterial)
        )
        .ignoresSafeArea(edges: .top)
    }
}
