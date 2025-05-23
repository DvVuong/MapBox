//
//  MapVC.swift
//  MapBox
//
//  Created by VuongDv on 23/5/25.
//

//import UIKit
//import MapboxMaps
//import GCDWebServer
//
//class MapVC: UIViewController {
//
//  private var mapView: MapView!
//  private let webServer = GCDWebServer()
//
//  override func viewDidLoad() {
//    super.viewDidLoad()
//    startLocalTileServer()
//    setupMapView()
//  }
//
//  private func setupMapView() {
//    let mapInitOptions = MapInitOptions(
//      styleURI: .satelliteStreets
//    )
//
//    mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
//    //  mapView.mapboxMap.mapStyle = .standardSatellite
//    view.addSubview(mapView)
//    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//
//    // Load style JSON từ bundle
//    if let styleURL = Bundle.main.url(forResource: "Style", withExtension: "json") {
//      do {
//        let styleJSON = try String(contentsOf: styleURL)
//        try mapView.mapboxMap.loadStyleJSON(styleJSON)
//        // mapView.mapboxMap.mapStyle = .light
//        mapView.camera.ease(
//          to: CameraOptions(center: CLLocationCoordinate2D(latitude: 40.680630, longitude: -73.696289), zoom: 12),
//          duration: 1.0
//        )
//      } catch {
//        print("❌ Failed to load style JSON: \(error)")
//      }
//    } else {
//      print("❌ style.json not found in bundle")
//    }
//  }
//
//  private func addLocalVectorOverlay() {
//    // 1. Add vector tile source
//    var vectorSource = VectorSource(id: "ny-polygons")
//    vectorSource.tiles = ["http://localhost:8080/{z}/{x}/{y}.pbf"]
//    vectorSource.minzoom = 0
//    vectorSource.maxzoom = 12
//
//    do {
//      try mapView.mapboxMap.style.addSource(vectorSource)
//    } catch {
//      print("❌ Add source error: \(error)")
//      return
//    }
//
//    // 2. Add polygon fill layer with transparent fill and blue outline
//    var fillLayer = FillLayer(id: "ny-polygons", source: "newyork-source")
//    fillLayer.source = "newyork-source"
//    fillLayer.sourceLayer = "newyork-source"
//    fillLayer.fillColor = .constant(StyleColor(.clear)) // Transparent
//    fillLayer.fillOutlineColor = .constant(StyleColor(.blue))
//    fillLayer.fillOpacity = .constant(1)
//
//    do {
//      try mapView.mapboxMap.style.addLayer(fillLayer)
//    } catch {
//      print("❌ Add layer error: \(error)")
//    }
//  }
//
//  private func startLocalTileServer() {
//    guard let tilePath = Bundle.main.path(forResource: "tiles", ofType: nil) else {
//      print("❌ Tile folder not found in bundle.")
//      return
//    }
//
//    webServer.addGETHandler(
//      forBasePath: "/",
//      directoryPath: tilePath,
//      indexFilename: nil,
//      cacheAge: 3600,
//      allowRangeRequests: true
//    )
//
//    do {
//      try webServer.start(options: [
//        GCDWebServerOption_Port: 8080,
//        GCDWebServerOption_BindToLocalhost: true,
//        GCDWebServerOption_AutomaticallySuspendInBackground: false
//      ])
//      print("✅ Tile server started: \(webServer.serverURL?.absoluteString ?? "unknown")")
//    } catch {
//      print("❌ Failed to start tile server: \(error)")
//    }
//  }
//
//  deinit {
//    webServer.stop()
//  }
//}

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

    fillLayer.fillOpacity = .constant(1.0)
    
    do {
      try mapView.mapboxMap.style.addLayer(fillLayer)
    } catch {
      print("❌ Error adding fill layer: \(error)")
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

//import UIKit
//import MapKit
//
//class MapVC: UIViewController {
//    
//    private var mapView: MKMapView!
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupMapView()
//        loadGeoJSONPolygons()
//    }
//
//    private func setupMapView() {
//        mapView = MKMapView(frame: view.bounds)
//        mapView.mapType = .standard
//        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        view.addSubview(mapView)
//        
//        // Zoom to NYC area
//        let center = CLLocationCoordinate2D(latitude: 40.680630, longitude: -73.696289)
//        let region = MKCoordinateRegion(center: center, latitudinalMeters: 10000, longitudinalMeters: 10000)
//        mapView.setRegion(region, animated: false)
//        mapView.delegate = self
//    }
//
//    private func loadGeoJSONPolygons() {
//        guard let url = Bundle.main.url(forResource: "buildings", withExtension: "geojson") else {
//            print("❌ GeoJSON file not found.")
//            return
//        }
//
//        do {
//            let data = try Data(contentsOf: url)
//            let features = try MKGeoJSONDecoder().decode(data)
//                .compactMap { $0 as? MKGeoJSONFeature }
//
//            for feature in features {
//                for geometry in feature.geometry {
//                    if let polygon = geometry as? MKPolygon {
//                        mapView.addOverlay(polygon)
//                    }
//                }
//            }
//        } catch {
//            print("❌ Failed to load GeoJSON: \(error)")
//        }
//    }
//}
//
//extension MapVC: MKMapViewDelegate {
//    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//        if let polygon = overlay as? MKPolygon {
//            let renderer = MKPolygonRenderer(polygon: polygon)
//            renderer.strokeColor = .blue
//            renderer.lineWidth = 2
//            renderer.fillColor = UIColor.clear
//            return renderer
//        }
//        return MKOverlayRenderer(overlay: overlay)
//    }
//}
