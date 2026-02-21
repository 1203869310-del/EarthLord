//
//  ResourceRow.swift
//  EarthLord
//
//  资源行：图标 + 名称 + 拥有量/需要量

import SwiftUI

struct ResourceRow: View {
    let resourceName: String
    let required: Int
    let owned: Int

    private var isSufficient: Bool { owned >= required }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.fill")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(resourceName)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                Text("\(owned)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                Text("/")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("\(required)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
