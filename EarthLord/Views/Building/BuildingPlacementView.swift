//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认 Sheet：选点、资源检查、确认建造

import SwiftUI
import CoreLocation

struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territoryId: String
    let territoryCoordinates: [CLLocationCoordinate2D]
    let onDismiss: () -> Void
    let onConstructionStarted: (PlayerBuilding) -> Void

    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var isBuilding = false
    @State private var errorMessage: String?

    private var resourcesForDisplay: [(name: String, required: Int, owned: Int)] {
        template.requiredResources.map { name, qty in
            (name: name, required: qty, owned: inventoryManager.getItemQuantity(name: name))
        }.sorted { $0.name < $1.name }
    }

    private var canBuild: Bool {
        resourcesForDisplay.allSatisfy { $0.owned >= $0.required }
    }

    private var formattedBuildTime: String {
        let s = template.buildTimeSeconds
        if s >= 3600 { return "\(s / 3600)h \((s % 3600) / 60)m" }
        if s >= 60 { return "\(s / 60)m \(s % 60)s" }
        return "\(s)s"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 建筑预览头部
                    VStack(spacing: 8) {
                        Text(template.icon)
                            .font(.system(size: 50))
                        Text(template.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.top, 8)

                    // 位置选择区
                    VStack(alignment: .leading, spacing: 8) {
                        Text("建造位置")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Button {
                            showLocationPicker = true
                        } label: {
                            HStack {
                                Image(systemName: selectedLocation == nil ? "mappin.slash" : "mappin.circle.fill")
                                    .foregroundColor(selectedLocation == nil ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)

                                if let loc = selectedLocation {
                                    Text(String(format: "%.5f, %.5f", loc.latitude, loc.longitude))
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)
                                } else {
                                    Text("点击地图选择位置")
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "map")
                                    .foregroundColor(ApocalypseTheme.primary)
                            }
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedLocation == nil
                                            ? ApocalypseTheme.textSecondary.opacity(0.3)
                                            : ApocalypseTheme.primary.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }

                    // 资源检查
                    VStack(alignment: .leading, spacing: 8) {
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

                    // 建造时间
                    HStack {
                        Label("建造时间", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                        Text(formattedBuildTime)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 错误信息
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .multilineTextAlignment(.center)
                    }

                    // 确认建造按钮
                    Button {
                        Task { await startConstruction() }
                    } label: {
                        HStack {
                            if isBuilding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "hammer.fill")
                            }
                            Text(isBuilding ? "建造中..." : "确认建造")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (selectedLocation == nil || !canBuild || isBuilding)
                                ? Color.gray
                                : ApocalypseTheme.primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(selectedLocation == nil || !canBuild || isBuilding)
                    .padding(.bottom)
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建造 \(template.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            BuildingLocationPickerView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: buildingManager.buildings(in: territoryId),
                buildingTemplates: buildingManager.buildingTemplates,
                onSelectLocation: { coord in
                    selectedLocation = coord
                    showLocationPicker = false
                },
                onCancel: { showLocationPicker = false }
            )
        }
    }

    private func startConstruction() async {
        isBuilding = true
        errorMessage = nil

        let result = await buildingManager.startConstruction(
            templateId: template.templateId,
            territoryId: territoryId,
            location: selectedLocation
        )

        isBuilding = false

        switch result {
        case .success(let building):
            onConstructionStarted(building)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
