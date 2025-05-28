//
//  GeoJsonLoader.swift
//  MapBox
//
//  Created by VuongDv on 23/5/25.
//

import Foundation
import MapKit

//class GeoJsonLoader {
//  static func loadGeoJSONFiles(from directory: String) -> [MKOverlay] {
//    var overlays: [MKOverlay] = []
//
//    guard let folderURL = Bundle.main.url(forResource: directory, withExtension: nil) else {
//      print("❌ Không tìm thấy thư mục \(directory)")
//      return []
//    }
//
//    let fileManager = FileManager.default
//    guard let fileURLs = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
//      print("❌ Không đọc được thư mục")
//      return []
//    }
//
//    for fileURL in fileURLs where fileURL.pathExtension == "geojson" {
//      if let data = try? Data(contentsOf: fileURL) {
//        if let features = try? MKGeoJSONDecoder().decode(data) as? [MKGeoJSONFeature] {
//          for feature in features {
//            for geometry in feature.geometry {
//              if let polygon = geometry as? MKPolygon {
//                overlays.append(polygon)
//              } else if let polyline = geometry as? MKPolyline {
//                overlays.append(polyline)
//              }
//            }
//          }
//        }
//      }
//    }
//
//    return overlays
//  }
//}


//import Foundation
//import MapKit
//
//struct TileInfo {
//  let fileName: String
//  let boundingMapRect: MKMapRect
//}
//
//class GeoJsonLoader {
//  static func loadTileMetadata(from directory: String) -> [TileInfo] {
//    guard let url = Bundle.main.url(forResource: "\(directory)/tile_metadata", withExtension: "json"),
//          let data = try? Data(contentsOf: url),
//          let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
//      print("[Debug] Failed to load tile metadata")
//      return []
//    }
//
//    return json.compactMap { dict in
//      guard let file = dict["file"] as? String,
//            let bounds = dict["bounds"] as? [Double], bounds.count == 4 else { return nil }
//
//      let minCoord = CLLocationCoordinate2D(latitude: bounds[1], longitude: bounds[0])
//      let maxCoord = CLLocationCoordinate2D(latitude: bounds[3], longitude: bounds[2])
//
//      let topLeft = MKMapPoint(minCoord)
//      let bottomRight = MKMapPoint(maxCoord)
//
//      let rect = MKMapRect(
//        origin: MKMapPoint(x: topLeft.x, y: topLeft.y),
//        size: MKMapSize(width: abs(bottomRight.x - topLeft.x),
//                        height: abs(bottomRight.y - topLeft.y))
//      )
//      print("[Debug] fileName: \(file)")
//      return TileInfo(fileName: file, boundingMapRect: rect)
//    }
//  }
//
//  static func loadGeoJSON(from fileName: String, in directory: String) -> [MKOverlay] {
//    print("[Debug] no GeoJSON file found fileName: \(fileName)")
//    guard let url = Bundle.main.url(forResource: "\(directory)/\(fileName)", withExtension: nil),
//          let data = try? Data(contentsOf: url) else {
//      print("[Debug] no GeoJSON file found")
//      return []
//    }
//
//    let decoder = MKGeoJSONDecoder()
//    guard let features = try? decoder.decode(data) as? [MKGeoJSONFeature] else { return [] }
//
//    return features.compactMap { feature in
//      feature.geometry.first as? MKOverlay
//    }
//  }
//}


class GeoJsonLoader {
    static func loadGeoJSONFile(inDirectory directory: String, filename: String) -> [MKOverlay] {
      guard let folderURL = Bundle.main.url(forResource: directory, withExtension: nil) else {
        print("[Debug] Không tìm thấy thư mục \(directory)")
        return []
      }
  
      let fileURL = folderURL.appendingPathComponent(filename)
  
      return loadGeoJSONFile(from: fileURL)
    }
  
    private static func loadGeoJSONFile(from fileURL: URL) -> [MKOverlay] {
      var overlays: [MKOverlay] = []
  
      do {
        let data = try Data(contentsOf: fileURL)
        let decoder = MKGeoJSONDecoder()
        let features = try decoder.decode(data) as? [MKGeoJSONFeature] ?? []
  
        for feature in features {
          for geometry in feature.geometry {
            if let polygon = geometry as? MKPolygon {
              overlays.append(polygon)
            } else if let polyline = geometry as? MKPolyline {
              overlays.append(polyline)
            }
          }
        }
      } catch {
        print("[Debug] Lỗi khi load file \(fileURL.lastPathComponent): \(error)")
      }
  
      return overlays
    }
  
//  // MARK: - Load GeoJson hiện thị theo Title
//  static func loadGeoJSONFile(named filename: String) -> [MKOverlay] {
//    guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
//      print("[Debug] Không tìm thấy file \(filename)")
//      return []
//    }
//    
//    do {
//      let data = try Data(contentsOf: url)
//      let decoder = MKGeoJSONDecoder()
//      let features = try decoder.decode(data) as? [MKGeoJSONFeature] ?? []
//      
//      var overlays: [MKOverlay] = []
//      
//      for feature in features {
//        for geometry in feature.geometry {
//          if let polygon = geometry as? MKPolygon {
//            overlays.append(polygon)
//          } else if let polyline = geometry as? MKPolyline {
//            overlays.append(polyline)
//          }
//        }
//      }
//      
//      return overlays
//    } catch {
//      print("[Debug] Lỗi khi load \(filename): \(error)")
//      return []
//    }
//  }
}
