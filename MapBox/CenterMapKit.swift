//
//  CenterMapKit.swift
//  MapBox
//
//  Created by VuongDv on 27/5/25.
//

// MARK: - Dùng để hiện thị theo center

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
import CoreGraphics

// Custom overlay cho ảnh raster
class ImageOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    var image: UIImage

    init(image: UIImage, boundingMapRect: MKMapRect, coordinate: CLLocationCoordinate2D) {
        self.image = image
        self.boundingMapRect = boundingMapRect
        self.coordinate = coordinate
    }
}

// Custom renderer cho overlay ảnh
class ImageOverlayRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? ImageOverlay else { return }
        let rect = self.rect(for: overlay.boundingMapRect)
        context.saveGState()
        context.setAlpha(1.0)
        context.draw(overlay.image.cgImage!, in: rect)
        context.restoreGState()
    }
}

class CenterMapViewController: UIViewController, MKMapViewDelegate {
  let mapView = MKMapView()
  var tiles: [GeoTile] = []
  
  var regionChangeWorkItem: DispatchWorkItem?
  
  var loadedTileFiles: Set<String> = []
  
  // Lưu mapping từ ObjectIdentifier của overlay tới tên file tile
  var overlayTileMap: [ObjectIdentifier: String] = [:]
  
  var imageOverlay: ImageOverlay?
  
  // Cache kết quả parse GeoJSON
  var geoJsonCache: [String: [MKPolygon]] = [:]
  
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
    
    // Vẽ overlay ảnh cho vùng nhìn thấy khi load xong
    drawVisiblePolygonsAsImageOverlay()
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
  
  func drawVisiblePolygonsAsImageOverlay() {
    // Chỉ render khi zoom đủ gần (latitudeDelta nhỏ hơn 1.0)
    if mapView.region.span.latitudeDelta > 0.01 {
      if let old = imageOverlay {
        mapView.removeOverlay(old)
        imageOverlay = nil
      }
      return
    }
    // 1. Lấy các polygon nằm trong visibleMapRect
    let visibleRect = mapView.visibleMapRect
    var visiblePolygons: [MKPolygon] = []
    for tile in tiles {
      if let cached = geoJsonCache[tile.file] {
        for polygon in cached {
          if visibleRect.intersects(polygon.boundingMapRect) {
            visiblePolygons.append(polygon)
          }
        }
      } else {
        let overlays = GeoJsonLoader.loadGeoJSONFile(inDirectory: "AlaskaTilePython3", filename: tile.file)
        let polygons = overlays.compactMap { $0 as? MKPolygon }
        geoJsonCache[tile.file] = polygons
        for polygon in polygons {
          if visibleRect.intersects(polygon.boundingMapRect) {
            visiblePolygons.append(polygon)
          }
        }
      }
    }
    guard !visiblePolygons.isEmpty else {
      if let old = imageOverlay {
        mapView.removeOverlay(old)
        imageOverlay = nil
      }
      return
    }
    // 2. Render ảnh cho vùng visibleRect
    let image = renderPolygonsToImage(polygons: visiblePolygons, boundingMapRect: visibleRect)
    let center = MKMapPoint(x: visibleRect.midX, y: visibleRect.midY).coordinate
    let overlay = ImageOverlay(image: image, boundingMapRect: visibleRect, coordinate: center)
    if let old = imageOverlay {
      mapView.removeOverlay(old)
    }
    imageOverlay = overlay
    mapView.addOverlay(overlay)
  }

  func renderPolygonsToImage(polygons: [MKPolygon], boundingMapRect: MKMapRect) -> UIImage {
    // Giới hạn kích thước ảnh tối đa
    let maxImageSize: CGFloat = 1024.0
    let mapRectWidth = CGFloat(boundingMapRect.size.width)
    let mapRectHeight = CGFloat(boundingMapRect.size.height)
    let scaleX = maxImageSize / mapRectWidth
    let scaleY = maxImageSize / mapRectHeight
    let scale = min(scaleX, scaleY, 1.0) // Không upscale nếu vùng nhỏ

    let width = mapRectWidth * scale
    let height = mapRectHeight * scale
    let size = CGSize(width: width, height: height)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
    context.setLineWidth(1.0)
    context.setStrokeColor(UIColor.yellow.cgColor)
    context.setFillColor(UIColor.clear.cgColor)
    for polygon in polygons {
        let path = UIBezierPath()
        let points = polygon.points()
        let count = polygon.pointCount
        for i in 0..<count {
            let mapPoint = points[i]
            let cgPoint = CGPoint(
                x: (CGFloat(mapPoint.x - boundingMapRect.origin.x) * scale),
                y: (height - (CGFloat(mapPoint.y - boundingMapRect.origin.y) * scale))
            )
            if i == 0 {
                path.move(to: cgPoint)
            } else {
                path.addLine(to: cgPoint)
            }
        }
        path.close()
        context.addPath(path.cgPath)
        context.drawPath(using: .stroke)
    }
    let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return image
  }

  // MARK: - MKMapViewDelegate
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    regionChangeWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      self.drawVisiblePolygonsAsImageOverlay()
    }
    regionChangeWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
  }
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let imageOverlay = overlay as? ImageOverlay {
      return ImageOverlayRenderer(overlay: imageOverlay)
    }
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
