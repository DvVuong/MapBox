//
//  MapKit.swift
//  MapBox
//
//  Created by VuongDv on 27/5/25.
//

import UIKit
import MapKit

class MapKitVC: UIViewController, MKMapViewDelegate {
    
    private var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
    }
    
    private func setupMapView() {
        mapView = MKMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
      mapView.mapType = .satellite // hoặc .satellite
        
        view.addSubview(mapView)
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(gesture)
        
        // Focus về New York như trước
        let center = CLLocationCoordinate2D(latitude: 40.680630, longitude: -73.696289)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 5000, longitudinalMeters: 5000)
        mapView.setRegion(region, animated: true)
        
        // ✅ Nếu có tile overlay bạn muốn dùng
        addTileOverlay()
    }
    
    private func addTileOverlay() {
        guard let tilePath = Bundle.main.resourcePath?.appending("/tiles") else {
            print("[Debug] Tile folder not found.")
            return
        }
        
        let template = "http://localhost:8080/{z}/{x}/{y}.png" // Nếu bạn export tile dạng raster
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false
        mapView.addOverlay(overlay)
    }
    
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        print("[Debug] Tapped at: \(coordinate.latitude), \(coordinate.longitude)")
        addAnnotation(at: coordinate)
    }
    
    private func addAnnotation(at coordinate: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Địa điểm đã chọn"
        mapView.addAnnotation(annotation)
    }
    
    // Nếu bạn dùng tile overlay hoặc polygon overlay
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }
        
        // Ví dụ với polygon
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = .yellow
            renderer.lineWidth = 2.0
            renderer.fillColor = UIColor.clear
            return renderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
}
