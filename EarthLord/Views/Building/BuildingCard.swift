//
//  BuildingCard.swift
//  EarthLord
//
//  建筑网格卡片：emoji 图标、名称、分类标签、资源摘要、Tier 徽章

import SwiftUI

struct BuildingCard: View {
    let template: BuildingTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.icon)
                        .font(.system(size: 32))

                    Spacer()

                    // Tier 徽章
                    Text("T\(template.tier)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ApocalypseTheme.primary)
                        .clipShape(Capsule())
                }

                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 分类标签
                Text(template.category.displayName)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ApocalypseTheme.primary.opacity(0.2))
                    .clipShape(Capsule())

                // 资源摘要（最多显示 2 项）
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(template.requiredResources.prefix(2)), id: \.key) { name, qty in
                        Text("· \(name) ×\(qty)")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    if template.requiredResources.count > 2 {
                        Text("· 更多...")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
