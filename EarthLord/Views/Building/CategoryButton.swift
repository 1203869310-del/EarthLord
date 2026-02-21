//
//  CategoryButton.swift
//  EarthLord
//
//  胶囊形建筑分类筛选按钮

import SwiftUI

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? ApocalypseTheme.primary
                        : ApocalypseTheme.cardBackground
                )
                .clipShape(Capsule())
        }
    }
}
