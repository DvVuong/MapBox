import UIKit
import MapboxMaps
import CoreLocation

class MapBoxVC: UIViewController {
  
  private var mapView: MapView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let options = MapInitOptions(
      cameraOptions: CameraOptions(
        center: CLLocationCoordinate2D(latitude: 40.680630, longitude: -73.696289), // từ metadata .mbtiles
        zoom: 12
      ),
      styleURI: .streets
    )
    
    mapView = MapView(frame: view.bounds, mapInitOptions: options)
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(mapView)
    
    mapView.mapboxMap.onNext(event: .mapLoaded) { [weak self] _ in
      print("[Debug] 🗺️ Map đã load xong")
      self?.addOfflineVectorTileLayer()
    }
    
    mapView.mapboxMap.onNext(event: .styleDataLoaded) { _ in
      print("[Debug] 🔄 styleDataLoaded triggered")
    }
    
    mapView.mapboxMap.onNext(event: .sourceDataLoaded) { event in
      print("[Debug] 📦 sourceDataLoaded for source: \(event.sourceId ?? "unknown")")
    }
  }
  
  private func addOfflineVectorTileLayer() {
    let fileManager = FileManager.default
    let bundleTilesFolder = "NewYorkTiles"
    
    let testTilePath = Bundle.main.bundlePath + "/\(bundleTilesFolder)/0/0/0.pbf"
    let tileFileExists = fileManager.fileExists(atPath: testTilePath)
    print("[Debug] 🧱 File 0/0/0.pbf exists? \(tileFileExists)")
    
    let tileURLTemplate = "file://\(Bundle.main.bundlePath)/\(bundleTilesFolder)/{z}/{x}/{y}.pbf"
    print("[Debug] 🗂️ Tile URL template: \(tileURLTemplate)")
    
    let sourceId = "newyork-source"
    let layerId = "buildings-layer"
    
    var source = VectorSource(id: sourceId)
    source.tiles = [tileURLTemplate]
    source.minzoom = 0
    source.maxzoom = 12
    
    do {
      if mapView.mapboxMap.style.sourceExists(withId: sourceId) {
        try mapView.mapboxMap.style.removeSource(withId: sourceId)
      }
      
      try mapView.mapboxMap.style.addSource(source)
      print("[Debug] ✅ Đã thêm vector source")
      
      var layer = FillLayer(id: layerId, source: sourceId)
      layer.sourceLayer = "buildings" // khớp với metadata mbtiles
      layer.fillColor = .constant(StyleColor(.systemBlue))
      layer.fillOpacity = .constant(0.7)
      
      if mapView.mapboxMap.style.layerExists(withId: layerId) {
        try mapView.mapboxMap.style.removeLayer(withId: layerId)
      }
      
      try mapView.mapboxMap.style.addLayer(layer)
      print("[Debug] ✅ Đã thêm fill layer")
      
      // Di chuyển camera đến center từ metadata mbtiles
      let centerCoordinate = CLLocationCoordinate2D(latitude: 40.680630, longitude: -73.696289)
      mapView.mapboxMap.setCamera(to: CameraOptions(center: centerCoordinate, zoom: 12))
      
      // Test truy vấn feature
      let point = mapView.mapboxMap.point(for: centerCoordinate)
      let queryOptions = RenderedQueryOptions(layerIds: [layerId], filter: nil)
      
      mapView.mapboxMap.queryRenderedFeatures(with: point, options: queryOptions) { result in
        switch result {
        case .success(let features):
          print("[Debug] 🧪 Feature count at center: \(features.count)")
          if let first = features.first {
                     // `first` là QueriedRenderedFeature
                     // Truy cập các thuộc tính JSON
//            if let properties = first.queriedFeature {
//                         print("[Debug] 🔍 Properties of first feature:")
//                         for (key, value) in properties {
//                             print(" - \(key): \(value)")
//                         }
//                     } else {
//                         print("[Debug] No properties found in feature")
//                     }
                 }
        case .failure(let error):
          print("[Debug] ❌ Query failed: \(error)")
        }
      }
      
    } catch {
      print("[Debug] ❌ Lỗi khi thêm vector source/layer: \(error)")
    }
  }
}
