//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  建筑选点 Sheet：在领地内点击地图选择建造位置

import SwiftUI
import MapKit

// MARK: - BuildingLocationPickerView

struct BuildingLocationPickerView: View {
    /// 领地坐标（已是 GCJ-02，直接使用）
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [BuildingTemplate]
    let onSelectLocation: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    @State private var selectedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            ZStack {
                LocationPickerMapView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingTemplates,
                    selectedCoordinate: $selectedCoordinate
                )
                .ignoresSafeArea(edges: .bottom)

                // 提示文字
                VStack {
                    HStack {
                        Spacer()
                        Text(selectedCoordinate == nil ? "点击领地内选择位置" : "已选择位置")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(.trailing)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("选择建造位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        if let coord = selectedCoordinate {
                            onSelectLocation(coord)
                        }
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }
}

// MARK: - LocationPickerMapView (UIViewRepresentable)

struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [BuildingTemplate]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator

        // 末世滤镜
        applyApocalypseFilter(to: mapView)

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(
                coordinates: territoryCoordinates,
                count: territoryCoordinates.count
            )
            polygon.title = "territory"
            mapView.addOverlay(polygon, level: .aboveRoads)
        }

        // 设置地图区域为领地 bbox
        if let region = regionForCoordinates(territoryCoordinates) {
            mapView.setRegion(region, animated: false)
        }

        // 添加点击手势
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新已有建筑标注
        let oldBuildingAnnotations = mapView.annotations.compactMap { $0 as? BuildingAnnotation }
        mapView.removeAnnotations(oldBuildingAnnotations)

        for building in existingBuildings {
            guard building.coordinate != nil else { continue }
            let tmpl = buildingTemplates.first { $0.templateId == building.templateId }
            let ann = BuildingAnnotation(building: building, template: tmpl)
            mapView.addAnnotation(ann)
        }

        // 更新选点标注
        let oldPins = mapView.annotations.compactMap { $0 as? MKPointAnnotation }
        mapView.removeAnnotations(oldPins)
        if let coord = selectedCoordinate {
            let pin = MKPointAnnotation()
            pin.coordinate = coord
            pin.title = "建造位置"
            mapView.addAnnotation(pin)
        }
    }

    // MARK: - Helpers

    private func applyApocalypseFilter(to mapView: MKMapView) {
        guard let colorControls = CIFilter(name: "CIColorControls") else { return }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else { return }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)
        mapView.layer.filters = [colorControls, sepiaFilter]
    }

    private func regionForCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let latDelta = (lats.max()! - lats.min()!) * 2.0
        let lonDelta = (lons.max()! - lons.min()!) * 2.0
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.001),
                longitudeDelta: max(lonDelta, 0.001)
            )
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView
        var territoryPolygonOverlay: MKPolygon?

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)

            // 射线法验证点在领地多边形内
            guard isPointInPolygon(point: coord, polygon: parent.territoryCoordinates) else {
                return
            }

            parent.selectedCoordinate = coord
        }

        /// 射线法：判断点是否在多边形内
        private func isPointInPolygon(
            point: CLLocationCoordinate2D,
            polygon: [CLLocationCoordinate2D]
        ) -> Bool {
            guard polygon.count >= 3 else { return false }
            var isInside = false
            let x = point.longitude
            let y = point.latitude
            var j = polygon.count - 1
            for i in 0..<polygon.count {
                let xi = polygon[i].longitude, yi = polygon[i].latitude
                let xj = polygon[j].longitude, yj = polygon[j].latitude
                let intersect = ((yi > y) != (yj > y)) &&
                                (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
                if intersect { isInside.toggle() }
                j = i
            }
            return isInside
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon, polygon.title == "territory" {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is MKPointAnnotation {
                let id = "SelectedPin"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                }
                view?.annotation = annotation
                view?.markerTintColor = .systemYellow
                view?.glyphImage = UIImage(systemName: "hammer.fill")
                return view
            }

            if let buildingAnn = annotation as? BuildingAnnotation {
                let id = "BuildingPin"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnn, reuseIdentifier: id)
                    view?.canShowCallout = true
                }
                view?.annotation = buildingAnn
                view?.markerTintColor = buildingAnn.building.status == .active ? .systemGreen : .systemBlue
                view?.glyphImage = UIImage(systemName: "building.2.fill")
                return view
            }

            return nil
        }
    }
}
