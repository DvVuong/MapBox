//
//  MapVC.swift
//  MapBox
//
//  Created by VuongDv on 23/5/25.
//

import UIKit
import MapboxMaps
import GCDWebServer

class MapVC: UIViewController {
  
  private var mapView: MapView!
  private let webServer = GCDWebServer()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    startLocalTileServer()
    setupMapView()
  }
  
  private func setupMapView() {
    let mapInitOptions = MapInitOptions(styleURI: .satelliteStreets)
    mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(mapView)
    
    // 👇 Thêm gesture recognizer
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
    mapView.addGestureRecognizer(tapGesture)
    
    mapView.mapboxMap.onNext(event: .styleLoaded) { [weak self] _ in
      self?.addLocalVectorOverlay()
      self?.mapView.camera.ease(
        to: CameraOptions(
          center: CLLocationCoordinate2D(latitude: 40.680630, longitude: -73.696289),
          zoom: 12
        ),
        duration: 1.0
      )
    }
  }
  
  private func addLocalVectorOverlay() {
    // 1. Add vector tile source
    var vectorSource = VectorSource(id: "newyork-source")
    vectorSource.tiles = ["http://localhost:8080/{z}/{x}/{y}.pbf"]
    vectorSource.minzoom = 0
    vectorSource.maxzoom = 12
    
    do {
      try mapView.mapboxMap.style.addSource(vectorSource)
    } catch {
      print("❌ Error adding source: \(error)")
      return
    }
    
    // 2. Add fill layer with transparent fill and blue outline
    var fillLayer = FillLayer(id: "ny-polygons", source: "newyork-source")
    fillLayer.source = "newyork-source"
    fillLayer.sourceLayer = "newyork-source"
    fillLayer.fillColor = .constant(StyleColor(UIColor.clear))            // Transparent fill
    fillLayer.fillOutlineColor = .constant(StyleColor(UIColor.yellow))      // Blue outline
    fillLayer.fillEmissiveStrength = .constant(0.0)
    fillLayer.fillOpacity = .constant(1.0)
    
    do {
      try mapView.mapboxMap.style.addLayer(fillLayer)
    } catch {
      print("❌ Error adding fill layer: \(error)")
    }
    
    
    // 3. Add line layer for outlines with thickness
    var lineLayer = LineLayer(id: "ny-polygons-outline", source: "newyork-source")
    lineLayer.sourceLayer = "newyork-source"
    lineLayer.lineColor = .constant(StyleColor(.yellow))
    lineLayer.lineWidth = .constant(2.0) // 👈 Adjust thickness here
    lineLayer.lineOpacity = .constant(1.0)
    
    do {
      try mapView.mapboxMap.style.addLayer(lineLayer)
    } catch {
      print("❌ Error adding line layer: \(error)")
    }
  }
  
  private func startLocalTileServer() {
    guard let tilePath = Bundle.main.path(forResource: "tiles", ofType: nil) else {
      print("❌ Tile folder not found in bundle.")
      return
    }
    
    webServer.addGETHandler(
      forBasePath: "/",
      directoryPath: tilePath,
      indexFilename: nil,
      cacheAge: 3600,
      allowRangeRequests: true
    )
    
    do {
      try webServer.start(options: [
        GCDWebServerOption_Port: 8080,
        GCDWebServerOption_BindToLocalhost: true,
        GCDWebServerOption_AutomaticallySuspendInBackground: false
      ])
      print("✅ Tile server started: \(webServer.serverURL?.absoluteString ?? "unknown")")
    } catch {
      print("❌ Failed to start tile server: \(error)")
    }
  }
  
  deinit {
    webServer.stop()
  }
}

extension MapVC {
  @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
    let tapPoint = gesture.location(in: mapView)
    
    // Chuyển từ CGPoint sang CLLocationCoordinate2D
    let coordinate = mapView.mapboxMap.coordinate(for: tapPoint)
    
    print("📍 Tapped at: \(coordinate.latitude), \(coordinate.longitude)")
    
    addAnnotation(at: coordinate)
  }
  
  private func addAnnotation(at coordinate: CLLocationCoordinate2D) {
    // Xoá các annotation cũ nếu muốn
  //  mapView.annotations.removeAll()
    
    // Tạo point annotation
    var pointAnnotation = PointAnnotation(coordinate: coordinate)
    pointAnnotation.image = .init(image: UIImage(systemName: "mappin")!, name: "mappin") // Use your custom icon if needed
    pointAnnotation.userInfo = ["title": "Địa điểm đã chọn"] // Custom info
    
    let annotationManager = mapView.annotations.makePointAnnotationManager()
    annotationManager.annotations = [pointAnnotation]
    
    // Hoặc bạn có thể dùng custom view như Callout nếu cần hiển thị nhiều info hơn
  }
}
