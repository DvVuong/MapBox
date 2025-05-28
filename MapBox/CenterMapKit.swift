//
//  CenterMapKit.swift
//  MapBox
//
//  Created by VuongDv on 27/5/25.
//

// MARK: - Dùng để hiện thị theo center
import UIKit
import MapKit

struct GeoTile: Codable {
  let file: String
  let bounds: [Double]
  
  func contains(center: CLLocationCoordinate2D) -> Bool {
    guard bounds.count == 4 else { return false }
    
    let longMin = bounds[0]
    let latMin = bounds[1]
    let longMax = bounds[2]
    let latMax = bounds[3]
    
    return center.longitude >= longMin &&
    center.longitude <= longMax &&
    center.latitude >= latMin &&
    center.latitude <= latMax
  }
}

import CoreLocation
import UIKit
import MapKit

class CenterMapViewController: UIViewController, MKMapViewDelegate {
  let mapView = MKMapView()
  var tiles: [GeoTile] = []
  
  var loadedTileFiles: Set<String> = []
  
  // Lưu mapping từ ObjectIdentifier của overlay tới tên file tile
  var overlayTileMap: [ObjectIdentifier: String] = [:]
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(mapView)
    mapView.frame = view.bounds
    mapView.mapType = .satellite
    mapView.delegate = self
    
    loadTileMetadata()
    
    // Zoom đến một vùng trong Alaska
    let alaskaCenter = CLLocationCoordinate2D(latitude: 61.1, longitude: -149.8)
    let region = MKCoordinateRegion(center: alaskaCenter,
                                    span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 10))
    mapView.setRegion(region, animated: false)
  }
  
  func loadTileMetadata() {
    guard let url = Bundle.main.url(forResource: "tile_metadata", withExtension: "json", subdirectory: "AlaskaTilePython3") else {
      print("[Debug] Không tìm thấy file Tiles/tiles.json")
      return
    }
    
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      tiles = try decoder.decode([GeoTile].self, from: data)
      print("[Debug] Đã load \(tiles.count) tile từ file JSON.")
    } catch {
      print("[Debug] Lỗi khi load tile metadata: \(error)")
    }
  }
  
  func loadTilesVisible(at center: CLLocationCoordinate2D) {
    // Tìm tiles cần load (center nằm trong bounds)
    let neededTiles = tiles.filter { $0.contains(center: center) }
    let neededFiles = Set(neededTiles.map { $0.file })
    
    // Lấy danh sách tiles hiện đang được load (từ overlayTileMap)
    let loadedFiles = Set(overlayTileMap.values)
    
    // Xoá overlay của tiles không còn cần
    let tilesToRemove = loadedFiles.subtracting(neededFiles)
    for fileToRemove in tilesToRemove {
      // Tìm overlay có file đó để remove
      let overlaysToRemove = overlayTileMap.filter { $0.value == fileToRemove }
      for (id, _) in overlaysToRemove {
        if let overlay = mapView.overlays.first(where: { ObjectIdentifier($0) == id }) {
          mapView.removeOverlay(overlay)
        }
        overlayTileMap.removeValue(forKey: id)
      }
    }
    
    // Load overlays cho tiles mới (chưa load)
    let tilesToLoad = neededTiles.filter { !loadedFiles.contains($0.file) }.prefix(2)
    for tile in tilesToLoad {
      DispatchQueue.global(qos: .userInitiated).async {
        print("[Debugtile] Loading tile \(tile.file)")
        let overlays = GeoJsonLoader.loadGeoJSONFile(inDirectory: "AlaskaTilePython3", filename: tile.file)
        
        DispatchQueue.main.async {[weak self] in
          guard let self else {
            return
          }
          for overlay in overlays {
            mapView.addOverlay(overlay)
            overlayTileMap[ObjectIdentifier(overlay)] = tile.file
          }
        }
      }
    }
  }
  
  func clearTiles() {
    mapView.removeOverlays(mapView.overlays)
    loadedTileFiles.removeAll()
  }
  

  // MARK: - MKMapViewDelegate
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    let span = mapView.region.span
    let minLatitudeDelta: CLLocationDegrees = 0.01
    let minLongitudeDelta: CLLocationDegrees = 0.01
    if span.latitudeDelta <= minLatitudeDelta && span.longitudeDelta <= minLongitudeDelta {
      loadTilesVisible(at: mapView.region.center)
      print("[Debug] center:\(mapView.region.center)")
    } else {
      clearTiles()
    }
  }
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let polygon = overlay as? MKPolygon {
      let renderer = MKPolygonRenderer(polygon: polygon)
      renderer.fillColor = .clear
      renderer.strokeColor = .yellow
      renderer.lineWidth = 1
      return renderer
    } else if let polyline = overlay as? MKPolyline {
      let renderer = MKPolylineRenderer(polyline: polyline)
      renderer.strokeColor = .red
      renderer.lineWidth = 1
      return renderer
    }
    return MKOverlayRenderer()
  }
}
