//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览 Sheet：分类筛选 + 网格展示

import SwiftUI

struct BuildingBrowserView: View {
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @StateObject private var buildingManager = BuildingManager.shared
    @State private var selectedCategory: BuildingCategory?
    @State private var selectedTemplateForDetail: BuildingTemplate?

    private var filteredTemplates: [BuildingTemplate] {
        guard let cat = selectedCategory else {
            return buildingManager.buildingTemplates
        }
        return buildingManager.buildingTemplates.filter { $0.category == cat }
    }

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryButton(
                            title: "全部",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        ForEach(BuildingCategory.allCases, id: \.self) { cat in
                            CategoryButton(
                                title: cat.displayName,
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(ApocalypseTheme.cardBackground)

                // 建筑网格
                ScrollView {
                    if filteredTemplates.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.2.slash")
                                .font(.system(size: 50))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Text("暂无可用建筑")
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(.top, 80)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(filteredTemplates) { template in
                                BuildingCard(template: template) {
                                    selectedTemplateForDetail = template
                                }
                            }
                        }
                        .padding()
                    }
                }
                .background(ApocalypseTheme.background)
            }
            .navigationTitle("选择建筑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onDismiss() }
                }
            }
        }
        .sheet(item: $selectedTemplateForDetail) { template in
            BuildingDetailView(
                template: template,
                onDismiss: { selectedTemplateForDetail = nil },
                onStartConstruction: { tmpl in
                    selectedTemplateForDetail = nil
                    onStartConstruction(tmpl)
                }
            )
        }
    }
}
