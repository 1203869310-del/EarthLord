//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页面 - 全屏地图布局，支持建筑浏览/建造/管理

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    @State private var territory: Territory
    var onDelete: (() -> Void)?

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        _territory = State(initialValue: territory)
        self.onDelete = onDelete
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var territoryManager = TerritoryManager.shared

    // MARK: - Sheet 状态

    @State private var showBuildingBrowser = false
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    // MARK: - UI 状态

    @State private var showInfoPanel = true
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var localName: String = ""

    // MARK: - 坐标转换

    private var territoryCoordinates: [CLLocationCoordinate2D] {
        CoordinateConverter.convertPath(territory.toCoordinates())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 底层：全屏地图
            TerritoryMapView(
                territoryCoordinates: territoryCoordinates,
                buildings: buildingManager.buildings(in: territory.id),
                templates: buildingManager.buildingTemplates
            )
            .ignoresSafeArea()

            // 顶部：工具栏
            VStack {
                TerritoryToolbarView(
                    territoryName: localName,
                    onDismiss: { dismiss() },
                    onBuildingBrowser: { showBuildingBrowser = true },
                    showInfoPanel: $showInfoPanel
                )
                Spacer()
            }

            // 底部：可折叠信息面板
            VStack {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.3), value: showInfoPanel)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            localName = territory.displayName
            Task { await buildingManager.fetchPlayerBuildings(territoryId: territory.id) }
        }
        // 建筑浏览 Sheet
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        // 建造确认 Sheet
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: territoryCoordinates,
                onDismiss: { selectedTemplateForConstruction = nil },
                onConstructionStarted: { _ in
                    selectedTemplateForConstruction = nil
                    Task { await buildingManager.fetchPlayerBuildings(territoryId: territory.id) }
                }
            )
        }
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("新名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("确认") { Task { await renameTerritory() } }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { Task { await deleteTerritory() } }
        } message: {
            Text("删除后无法恢复，确定删除这块领地吗？")
        }
    }

    // MARK: - Info Panel

    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动把手
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名 + 重命名按钮
                    HStack {
                        Text(localName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        Button {
                            newName = localName
                            showRenameAlert = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 22))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    // 统计信息
                    HStack(spacing: 16) {
                        statBadge(icon: "square.dashed", value: territory.formattedArea, label: "面积")
                        if let pts = territory.pointCount {
                            statBadge(icon: "mappin.circle", value: "\(pts)", label: "边界点")
                        }
                        statBadge(icon: "calendar", value: territory.formattedDate, label: "创建")
                    }

                    // 建筑列表
                    let buildings = buildingManager.buildings(in: territory.id)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("建筑")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Text("\(buildings.count) 个")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        if buildings.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: "hammer")
                                        .font(.system(size: 28))
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                    Text("点击 建造 开始建设")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(buildings) { building in
                                    TerritoryBuildingRow(
                                        building: building,
                                        template: buildingManager.getTemplate(for: building.templateId),
                                        onUpgrade: {
                                            Task {
                                                let result = await buildingManager.upgradeBuilding(buildingId: building.id)
                                                if case .failure(let err) = result {
                                                    print("[TerritoryDetail] 升级失败: \(err)")
                                                }
                                            }
                                        },
                                        onDemolish: {
                                            Task {
                                                await buildingManager.demolishBuilding(buildingId: building.id)
                                            }
                                        }
                                    )
                                    if building.id != buildings.last?.id {
                                        Divider()
                                            .background(ApocalypseTheme.textSecondary.opacity(0.2))
                                    }
                                }
                            }
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // 删除按钮
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeleting ? "删除中..." : "删除领地")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isDeleting)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .background(
            ApocalypseTheme.background.opacity(0.92)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Methods

    private func renameTerritory() async {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let success = await TerritoryManager.shared.updateTerritoryName(
            territoryId: territory.id,
            newName: trimmed
        )
        if success {
            localName = trimmed
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
        }
    }

    private func deleteTerritory() async {
        isDeleting = true
        let success = await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)
        isDeleting = false
        if success {
            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
            onDelete?()
            dismiss()
        }
    }
}

