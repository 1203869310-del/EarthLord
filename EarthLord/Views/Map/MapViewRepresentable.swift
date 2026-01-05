//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格的地图 + 轨迹渲染
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable

/// 末世风格地图视图
/// 使用 UIViewRepresentable 包装 MKMapView，应用末世滤镜效果
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户当前位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 路径坐标数组（用于绘制轨迹）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    // MARK: - Properties

    /// 路径更新版本号（触发重绘）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否已闭合（闭环后轨迹变色 + 填充多边形）
    var isPathClosed: Bool

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型：卫星图 + 道路标签（末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！这会触发 MapKit 开始获取位置）
        mapView.showsUserLocation = true

        // 允许用户交互
        mapView.isZoomEnabled = true      // 允许双指缩放
        mapView.isScrollEnabled = true    // 允许单指拖动
        mapView.isRotateEnabled = true    // 允许旋转
        mapView.isPitchEnabled = true     // 允许倾斜

        // 设置代理（关键！否则 didUpdate userLocation 和 rendererFor overlay 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        // 设置初始区域（默认显示中国区域）
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        mapView.setRegion(defaultRegion, animated: false)

        return mapView
    }

    /// 更新 MKMapView（SwiftUI 状态变化时调用）
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新轨迹显示（传入闭环状态）
        context.coordinator.updateTrackingPath(on: mapView, coordinates: trackingPath, isPathClosed: isPathClosed)
    }

    /// 创建 Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末世滤镜效果
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else { return }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else { return }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)

        // 应用滤镜到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]
    }

    // MARK: - Coordinator

    /// 地图代理协调器
    /// 处理地图事件，实现自动居中到用户位置，渲染轨迹
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复居中，不影响用户手动拖动）
        private var hasInitialCentered = false

        /// 当前轨迹 Overlay（用于更新时移除旧轨迹）
        private var currentPathOverlay: MKPolyline?

        /// 当前多边形 Overlay（闭环后填充区域）
        private var currentPolygonOverlay: MKPolygon?

        /// 当前路径是否已闭合（用于轨迹变色）
        private var isCurrentPathClosed = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - 轨迹更新方法

        /// 更新轨迹显示
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - coordinates: 原始 WGS-84 坐标数组
        ///   - isPathClosed: 路径是否已闭合
        func updateTrackingPath(on mapView: MKMapView, coordinates: [CLLocationCoordinate2D], isPathClosed: Bool) {
            // 更新闭环状态
            isCurrentPathClosed = isPathClosed

            // 移除旧的轨迹
            if let oldOverlay = currentPathOverlay {
                mapView.removeOverlay(oldOverlay)
                currentPathOverlay = nil
            }

            // 移除旧的多边形
            if let oldPolygon = currentPolygonOverlay {
                mapView.removeOverlay(oldPolygon)
                currentPolygonOverlay = nil
            }

            // 如果坐标少于 2 个点，无法绘制线条
            guard coordinates.count >= 2 else { return }

            // 【关键】坐标转换：WGS-84 → GCJ-02
            // 不转换的话，轨迹会偏移 100-500 米！
            let convertedCoordinates = CoordinateConverter.convertPath(coordinates)

            // 创建 MKPolyline
            let polyline = MKPolyline(coordinates: convertedCoordinates, count: convertedCoordinates.count)

            // 添加到地图
            mapView.addOverlay(polyline)

            // 保存引用，下次更新时移除
            currentPathOverlay = polyline

            // 【闭环后填充多边形】
            if isPathClosed && convertedCoordinates.count >= 3 {
                // 创建闭合多边形
                let polygon = MKPolygon(coordinates: convertedCoordinates, count: convertedCoordinates.count)

                // 添加到地图（在轨迹下方）
                mapView.insertOverlay(polygon, below: polyline)

                // 保存引用
                currentPolygonOverlay = polygon

                print("🗺️ [轨迹渲染] 闭环成功，绘制多边形填充区域")
            }

            print("🗺️ [轨迹渲染] 绘制 \(coordinates.count) 个点的轨迹，闭环状态: \(isPathClosed)")
        }

        // MARK: - MKMapViewDelegate

        /// 用户位置更新时调用（关键方法！）
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置坐标
            guard let location = userLocation.location else { return }

            // 更新绑定的位置（通知外部）
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约 1 公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// 【关键】渲染 Overlay（轨迹线 + 多边形填充）
        /// 如果不实现这个方法，addOverlay 添加的轨迹不会显示！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理 MKPolygon（闭环填充区域）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 填充色：半透明绿色
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)

                // 边框色：绿色
                renderer.strokeColor = UIColor.systemGreen

                // 边框宽度
                renderer.lineWidth = 2.0

                return renderer
            }

            // 处理 MKPolyline（轨迹线）
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 【轨迹变色】根据闭环状态选择颜色
                // 未闭环：青色；已闭环：绿色
                if isCurrentPathClosed {
                    renderer.strokeColor = UIColor.systemGreen
                } else {
                    renderer.strokeColor = UIColor.systemCyan
                }

                renderer.lineWidth = 4.0
                renderer.lineCap = .round
                renderer.lineJoin = .round

                // 添加半透明效果，更有科幻感
                renderer.alpha = 0.8

                return renderer
            }

            // 默认返回空渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 地图区域变化完成时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于记录用户浏览的区域
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图瓦片加载完成
        }

        /// 渲染用户位置标注（可自定义蓝点样式）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用系统默认蓝点
            if annotation is MKUserLocation {
                return nil
            }
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false
    )
}
