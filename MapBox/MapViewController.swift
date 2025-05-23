//import UIKit
//import MapKit
//
//class MapViewController: UIViewController, MKMapViewDelegate {
//    let mapView = MKMapView()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        mapView.frame = view.bounds
//        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        mapView.delegate = self
//        view.addSubview(mapView)
//
//        loadGeoJSONFilesFromBundle()
//    }
//
//    func loadGeoJSONFilesFromBundle() {
//        guard let alaskaTileFolderURL = Bundle.main.resourceURL?.appendingPathComponent("AlaskaTile") else {
//            print("Không tìm thấy thư mục AlaskaTile trong bundle.")
//            return
//        }
//
//        let fileManager = FileManager.default
//        guard let geojsonURLs = try? fileManager.contentsOfDirectory(at: alaskaTileFolderURL, includingPropertiesForKeys: nil)
//                .filter({ $0.pathExtension == "geojson" }) else {
//            print("Không có file GeoJSON nào.")
//            return
//        }
//
//        var boundingMapRect: MKMapRect?
//
//        for url in geojsonURLs {
//            do {
//                let data = try Data(contentsOf: url)
//                let features = try MKGeoJSONDecoder().decode(data)
//                    .compactMap { $0 as? MKGeoJSONFeature }
//
//                for feature in features {
//                    for geometry in feature.geometry {
//                        if let polygon = geometry as? MKPolygon {
//                            mapView.addOverlay(polygon)
//                            let rect = polygon.boundingMapRect
//                            boundingMapRect = boundingMapRect?.union(rect) ?? rect
//                        } else if let polyline = geometry as? MKPolyline {
//                            mapView.addOverlay(polyline)
//                            let rect = polyline.boundingMapRect
//                            boundingMapRect = boundingMapRect?.union(rect) ?? rect
//                        }
//                    }
//                }
//            } catch {
//                print("Lỗi đọc file \(url.lastPathComponent): \(error)")
//            }
//        }
//
//        // Zoom đến vùng dữ liệu
//        if let rect = boundingMapRect {
//            mapView.setVisibleMapRect(rect,
//                                      edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
//                                      animated: true)
//        }
//    }
//
//    // Hiển thị overlay
//    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//        if let polygon = overlay as? MKPolygon {
//            let renderer = MKPolygonRenderer(polygon: polygon)
//            renderer.strokeColor = .blue
//            renderer.fillColor = UIColor.blue.withAlphaComponent(0.2)
//            renderer.lineWidth = 1
//            return renderer
//        } else if let polyline = overlay as? MKPolyline {
//            let renderer = MKPolylineRenderer(polyline: polyline)
//            renderer.strokeColor = .red
//            renderer.lineWidth = 2
//            return renderer
//        }
//        return MKOverlayRenderer(overlay: overlay)
//    }
//}

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {
  
  let mapView = MKMapView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(mapView)
    mapView.frame = view.bounds
    mapView.mapType = .satellite
    mapView.delegate = self
    
    addPolygonFromCoordinates()
  }
  
  func addPolygonFromCoordinates() {
    // Tọa độ từ GeoJSON bạn gửi
    let coordinates = [
      CLLocationCoordinate2D(latitude: 64.834475, longitude: -147.379958),
      CLLocationCoordinate2D(latitude: 64.834476, longitude: -147.380221),
      CLLocationCoordinate2D(latitude: 64.834429, longitude: -147.380222),
      CLLocationCoordinate2D(latitude: 64.834427, longitude: -147.37996),
      CLLocationCoordinate2D(latitude: 64.834475, longitude: -147.379958) // đóng vòng
    ]
    
    let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
    mapView.addOverlay(polygon)
    
    // Tự động zoom tới polygon
    let mapRect = polygon.boundingMapRect
    mapView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)
  }
  
  // Hiển thị polygon với màu sắc
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let polygon = overlay as? MKPolygon {
      let renderer = MKPolygonRenderer(polygon: polygon)
      renderer.fillColor = UIColor.clear
      renderer.strokeColor = UIColor.yellow
      renderer.lineWidth = 2
      return renderer
    }
    return MKOverlayRenderer()
  }
}
