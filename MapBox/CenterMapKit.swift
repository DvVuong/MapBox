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
    
    // Thêm gesture recognizer để bắt sự kiện tap
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
    mapView.addGestureRecognizer(tapGesture)
    
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
        let overlays = GeoJsonLoader.loadGeoJSONFile(inDirectory: "NewYorkTilePython", filename: tile.file)
        
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
  
  func areaOfPolygon(_ polygon: MKPolygon) -> Double {
    guard polygon.pointCount > 2 else { return 0 }
    let points = polygon.points()
    var area: Double = 0
    for i in 0..<polygon.pointCount {
      let p1 = points[i]
      let p2 = points[(i+1) % polygon.pointCount]
      area += (p1.x * p2.y - p2.x * p1.y)
    }
    return abs(area) / 2.0
  }
  
  func distanceToCenter(_ polygon: MKPolygon, center: MKMapPoint) -> Double {
    let boundingRect = polygon.boundingMapRect
    let polyCenter = MKMapPoint(x: boundingRect.midX, y: boundingRect.midY)
    let dx = polyCenter.x - center.x
    let dy = polyCenter.y - center.y
    return sqrt(dx*dx + dy*dy)
  }
  
  func drawVisiblePolygonsAsImageOverlay() {
    if mapView.region.span.latitudeDelta > 0.05 {
        if let old = imageOverlay {
            mapView.removeOverlay(old)
            imageOverlay = nil
        }
        return
    }
    let visibleRect = mapView.visibleMapRect
    let geojsonFiles = listGeoJSONFiles(in: "AlaskaTilePython3")
    let centerMapPoint = MKMapPoint(x: visibleRect.midX, y: visibleRect.midY)
    
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        var visiblePolygons: [MKPolygon] = []
        for file in geojsonFiles {
            let overlays = GeoJsonLoader.loadGeoJSONFile(inDirectory: "AlaskaTilePython3", filename: file)
            let polygons = overlays.compactMap { $0 as? MKPolygon }
            for polygon in polygons {
                if visibleRect.intersects(polygon.boundingMapRect) {
                    visiblePolygons.append(polygon)
                }
            }
        }
        // Lọc theo diện tích lớn nhất và ưu tiên polygon gần tâm bản đồ
        let sortedPolygons = visiblePolygons.sorted {
            let area1 = self.areaOfPolygon($0)
            let area2 = self.areaOfPolygon($1)
            if abs(area1 - area2) > 1e-6 {
                return area1 > area2 // diện tích lớn lên trước
            } else {
                return self.distanceToCenter($0, center: centerMapPoint) < self.distanceToCenter($1, center: centerMapPoint)
            }
        }
        let limitedPolygons = Array(sortedPolygons.prefix(200))
        guard !limitedPolygons.isEmpty else {
            DispatchQueue.main.async {
                if let old = self.imageOverlay {
                    self.mapView.removeOverlay(old)
                    self.imageOverlay = nil
                }
            }
            return
        }
        let image = self.renderPolygonsToImage(polygons: limitedPolygons, boundingMapRect: visibleRect)
        let center = MKMapPoint(x: visibleRect.midX, y: visibleRect.midY).coordinate
        let overlay = ImageOverlay(image: image, boundingMapRect: visibleRect, coordinate: center)
        DispatchQueue.main.async {
            if let old = self.imageOverlay {
                self.mapView.removeOverlay(old)
            }
            self.imageOverlay = overlay
            self.mapView.addOverlay(overlay)
        }
    }
  }
  
  func listGeoJSONFiles(in directory: String) -> [String] {
    guard let resourcePath = Bundle.main.resourcePath else { return [] }
    let dirPath = (resourcePath as NSString).appendingPathComponent(directory)
    do {
      let files = try FileManager.default.contentsOfDirectory(atPath: dirPath)
      return files.filter { $0.hasSuffix(".geojson") }
    } catch {
      print("Lỗi khi đọc thư mục: \(error)")
      return []
    }
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
    context.setLineWidth(1.5)
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
  
  // MARK: - Xử lý tap để lấy địa chỉ và hiển thị info view
  @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
    let point = gesture.location(in: mapView)
    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
    // Reverse geocode
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
      guard let self = self else { return }
      var address = "Không tìm thấy địa chỉ"
      if let placemark = placemarks?.first {
        address = [
          placemark.name,
          placemark.thoroughfare,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].compactMap { $0 }.joined(separator: ", ")
      }
      self.showInfoView(at: point, address: address)
    }
  }
  
  func showInfoView(at point: CGPoint, address: String) {
    // Xoá view cũ nếu có
    mapView.subviews.filter { $0.tag == 9999 }.forEach { $0.removeFromSuperview() }
    // Tạo view mới
    let infoView = UILabel()
    infoView.tag = 9999
    infoView.text = address
    infoView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    infoView.textColor = .white
    infoView.font = UIFont.systemFont(ofSize: 14)
    infoView.numberOfLines = 0
    infoView.textAlignment = .center
    infoView.layer.cornerRadius = 8
    infoView.layer.masksToBounds = true
    let maxWidth: CGFloat = 220
    let size = infoView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
    let infoViewHeight: CGFloat = size.height + 20
    let infoViewY = mapView.bounds.height - infoViewHeight - 24
    infoView.frame = CGRect(
      x: (mapView.bounds.width - min(size.width, maxWidth) - 16) / 2,
      y: infoViewY,
      width: min(size.width, maxWidth) + 16,
      height: infoViewHeight
    )
    infoView.alpha = 0
    mapView.addSubview(infoView)
    UIView.animate(withDuration: 0.2) {
      infoView.alpha = 1
    }
    // KHÔNG tự động ẩn nữa!
  }
}
