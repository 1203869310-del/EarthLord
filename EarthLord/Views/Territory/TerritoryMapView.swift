//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地全屏地图：显示领地多边形 + 建筑标注，末世风格

import SwiftUI
import MapKit

struct TerritoryMapView: UIViewRepresentable {
    /// 领地坐标（已是 GCJ-02，直接使用）
    let territoryCoordinates: [CLLocationCoordinate2D]
    let buildings: [PlayerBuilding]
    let templates: [BuildingTemplate]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
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

        // 设置初始区域
        if let region = regionForCoordinates(territoryCoordinates) {
            mapView.setRegion(region, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.drawBuildings(on: mapView, buildings: buildings, templates: templates)
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
        let latDelta = (lats.max()! - lats.min()!) * 2.5
        let lonDelta = (lons.max()! - lons.min()!) * 2.5
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.002),
                longitudeDelta: max(lonDelta, 0.002)
            )
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        private var currentBuildingAnnotations: [BuildingAnnotation] = []

        func drawBuildings(
            on mapView: MKMapView,
            buildings: [PlayerBuilding],
            templates: [BuildingTemplate]
        ) {
            mapView.removeAnnotations(currentBuildingAnnotations)
            currentBuildingAnnotations.removeAll()

            for building in buildings {
                guard building.coordinate != nil else { continue }
                let tmpl = templates.first { $0.templateId == building.templateId }
                let ann = BuildingAnnotation(building: building, template: tmpl)
                mapView.addAnnotation(ann)
                currentBuildingAnnotations.append(ann)
            }
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

            if let buildingAnn = annotation as? BuildingAnnotation {
                let id = "TerritoryBuildingPin"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnn, reuseIdentifier: id)
                    view?.canShowCallout = true
                }
                view?.annotation = buildingAnn
                view?.markerTintColor = buildingAnn.building.status == .active
                    ? UIColor.systemYellow
                    : UIColor.systemBlue
                view?.glyphImage = UIImage(systemName: "building.2.fill")
                return view
            }

            return nil
        }
    }
}
