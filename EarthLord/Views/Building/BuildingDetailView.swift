//
//  BuildingDetailView.swift
//  EarthLord
//
//  建筑详情 Sheet：完整展示建筑信息 + 开始建造按钮

import SwiftUI

struct BuildingDetailView: View {
    let template: BuildingTemplate
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @StateObject private var inventoryManager = InventoryManager.shared

    private var resourcesForDisplay: [(name: String, required: Int, owned: Int)] {
        template.requiredResources.map { name, qty in
            (name: name, required: qty, owned: inventoryManager.getItemQuantity(name: name))
        }.sorted { $0.name < $1.name }
    }

    private var canAfford: Bool {
        resourcesForDisplay.allSatisfy { $0.owned >= $0.required }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 图标与标题
                    VStack(spacing: 8) {
                        Text(template.icon)
                            .font(.system(size: 60))

                        Text(template.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        HStack(spacing: 8) {
                            Text(template.category.displayName)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ApocalypseTheme.primary.opacity(0.2))
                                .clipShape(Capsule())

                            Text("T\(template.tier)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ApocalypseTheme.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)

                    // 描述
                    Text(template.description)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // 建造信息
                    VStack(spacing: 0) {
                        infoRow(
                            icon: "clock",
                            title: "建造时间",
                            value: formattedBuildTime
                        )
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(
                            icon: "building.2",
                            title: "每地上限",
                            value: "\(template.maxPerTerritory) 个"
                        )
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(
                            icon: "arrow.up.circle",
                            title: "最大等级",
                            value: "Lv.\(template.maxLevel)"
                        )
                    }
                    .background(ApocalypseTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 所需资源
                    VStack(alignment: .leading, spacing: 12) {
                        Text("所需资源")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        VStack(spacing: 8) {
                            ForEach(resourcesForDisplay, id: \.name) { item in
                                ResourceRow(
                                    resourceName: item.name,
                                    required: item.required,
                                    owned: item.owned
                                )
                            }
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 开始建造按钮
                    Button {
                        onStartConstruction(template)
                    } label: {
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("开始建造")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAfford ? ApocalypseTheme.primary : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canAfford)
                    .padding(.bottom)
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建筑详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onDismiss() }
                }
            }
        }
    }

    private var formattedBuildTime: String {
        let s = template.buildTimeSeconds
        if s >= 3600 {
            return "\(s / 3600)h \((s % 3600) / 60)m"
        } else if s >= 60 {
            return "\(s / 60)m \(s % 60)s"
        } else {
            return "\(s)s"
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
    }
}
