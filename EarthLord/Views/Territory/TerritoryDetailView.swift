//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页面 - 显示领地信息、地图预览、删除功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    let territory: Territory
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var territoryManager = TerritoryManager.shared

    // MARK: - State

    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    // MARK: - Computed Properties

    /// 转换后的坐标（用于地图显示）
    private var convertedCoordinates: [CLLocationCoordinate2D] {
        CoordinateConverter.convertPath(territory.toCoordinates())
    }

    /// 地图区域
    private var mapRegion: MKCoordinateRegion {
        let coords = convertedCoordinates
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35, longitude: 105),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        // 计算中心点
        let latitudes = coords.map { $0.latitude }
        let longitudes = coords.map { $0.longitude }
        let centerLat = (latitudes.min()! + latitudes.max()!) / 2
        let centerLon = (longitudes.min()! + longitudes.max()!) / 2

        // 计算 span
        let latDelta = (latitudes.max()! - latitudes.min()!) * 1.5
        let lonDelta = (longitudes.max()! - longitudes.min()!) * 1.5

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.002),
                longitudeDelta: max(lonDelta, 0.002)
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 领地信息
                    infoSection

                    // 未来功能占位
                    futureFeatures

                    // 删除按钮
                    deleteButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("删除后无法恢复，确定要删除这块领地吗？")
            }
        }
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Map(initialPosition: .region(mapRegion)) {
            // 绘制多边形
            if convertedCoordinates.count >= 3 {
                MapPolygon(coordinates: convertedCoordinates)
                    .foregroundStyle(.green.opacity(0.3))
                    .stroke(.green, lineWidth: 2)
            }
        }
        .mapStyle(.hybrid)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(true) // 禁止交互
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Text("领地信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            // 信息卡片
            VStack(spacing: 0) {
                infoRow(icon: "square.dashed", title: "面积", value: territory.formattedArea)
                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))

                if let pointCount = territory.pointCount {
                    infoRow(icon: "mappin.circle", title: "边界点数", value: "\(pointCount) 个")
                    Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                }

                infoRow(icon: "calendar", title: "创建时间", value: territory.formattedDate)
            }
            .background(ApocalypseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: - Future Features

    private var futureFeatures: some View {
        VStack(spacing: 12) {
            HStack {
                Text("更多功能")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            VStack(spacing: 0) {
                featureRow(icon: "pencil", title: "重命名领地", comingSoon: true)
                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))

                featureRow(icon: "building.2", title: "建筑系统", comingSoon: true)
                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))

                featureRow(icon: "arrow.left.arrow.right", title: "领地交易", comingSoon: true)
            }
            .background(ApocalypseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func featureRow(icon: String, title: String, comingSoon: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            if comingSoon {
                Text("敬请期待")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.warning.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
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
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.danger)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDeleting)
        .opacity(isDeleting ? 0.7 : 1)
        .padding(.top, 10)
    }

    // MARK: - Methods

    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            onDelete?()
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "user-id",
            name: "测试领地",
            path: [
                ["lat": 31.2, "lon": 121.4],
                ["lat": 31.2, "lon": 121.5],
                ["lat": 31.3, "lon": 121.5],
                ["lat": 31.3, "lon": 121.4]
            ],
            area: 12500,
            pointCount: 25,
            isActive: true,
            startedAt: nil,
            completedAt: nil,
            createdAt: "2025-01-08T10:00:00Z",
            bboxMinLat: 31.2,
            bboxMaxLat: 31.3,
            bboxMinLon: 121.4,
            bboxMaxLon: 121.5
        )
    )
}
