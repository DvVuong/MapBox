//
//  GridMapCenter.swift
//  MapBox
//
//  Created by VuongDv on 28/5/25.
//

import UIKit
import MapKit
import CoreLocation
import CoreGraphics

struct TileMeta: Codable {
    let file: String
    let bounds: [Double] // [minx, miny, maxx, maxy]
}

class GridMapCenter: UIViewController, MKMapViewDelegate {
    let mapView = MKMapView()
    var tileMetas: [TileMeta] = []
    var imageOverlay: MKOverlay?
    var geoJsonFileCache: [String: [MKPolygon]] = [:]
    let tileFolder = "NewYorkTilePython" // Đổi tên folder nếu cần
    let metaFile = "tile_metadata.json"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.mapType = .satellite
        mapView.delegate = self
        loadTileMetadata()
        let center = CLLocationCoordinate2D(latitude: 41.07132, longitude: -71.861665)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
        mapView.setRegion(region, animated: false)
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:))))
        drawVisiblePolygonsAsImageOverlay()
    }

    func loadTileMetadata() {
        guard let metaURL = Bundle.main.url(forResource: metaFile, withExtension: nil, subdirectory: tileFolder) else {
            print("[Debug] Không tìm thấy metadata")
            return
        }
        do {
            let data = try Data(contentsOf: metaURL)
            tileMetas = try JSONDecoder().decode([TileMeta].self, from: data)
        } catch {
            print("[Debug] Lỗi khi load metadata: \(error)")
        }
    }

    func drawVisiblePolygonsAsImageOverlay() {
        let visibleRect = mapView.visibleMapRect
        // Lọc tile có bounds giao với visibleRect
        let filesToLoad = tileMetas.filter {
            let b = $0.bounds
            let tileRect = MKMapRect(
                origin: MKMapPoint(CLLocationCoordinate2D(latitude: b[1], longitude: b[0])),
                size: MKMapSize(width: abs(b[2]-b[0])*MKMapPointsPerMeterAtLatitude(b[1]), height: abs(b[3]-b[1])*MKMapPointsPerMeterAtLatitude(b[1]))
            )
            return tileRect.intersects(visibleRect)
        }.map { $0.file }
        var visiblePolygons: [MKPolygon] = []
        for file in filesToLoad.prefix(10) { // chỉ load tối đa 10 tile gần nhất
            let polygons: [MKPolygon]
            if let cached = geoJsonFileCache[file] {
                polygons = cached
            } else {
                guard let overlays = loadGeoJSONFile(inDirectory: tileFolder, filename: file) else { continue }
                polygons = overlays.compactMap { $0 as? MKPolygon }
                geoJsonFileCache[file] = polygons
            }
            for polygon in polygons {
                if visibleRect.intersects(polygon.boundingMapRect) {
                    visiblePolygons.append(polygon)
                }
            }
        }
        // Giới hạn số polygon
        visiblePolygons = Array(visiblePolygons.prefix(200))
        guard !visiblePolygons.isEmpty else {
            if let old = imageOverlay {
                mapView.removeOverlay(old)
                imageOverlay = nil
            }
            return
        }
        let image = renderPolygonsToImage(polygons: visiblePolygons, boundingMapRect: visibleRect)
        let overlay = ImageOverlay(image: image, boundingMapRect: visibleRect, coordinate: MKMapPoint(x: visibleRect.midX, y: visibleRect.midY).coordinate)
        if let old = imageOverlay {
            mapView.removeOverlay(old)
        }
        imageOverlay = overlay
        mapView.addOverlay(overlay)
    }

    func loadGeoJSONFile(inDirectory directory: String, filename: String) -> [MKOverlay]? {
        guard let folderURL = Bundle.main.url(forResource: directory, withExtension: nil) else { return nil }
        let fileURL = folderURL.appendingPathComponent(filename)
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = MKGeoJSONDecoder()
            let features = try decoder.decode(data) as? [MKGeoJSONFeature] ?? []
            var overlays: [MKOverlay] = []
            for feature in features {
                for geometry in feature.geometry {
                    if let polygon = geometry as? MKPolygon {
                        overlays.append(polygon)
                    }
                }
            }
            return overlays
        } catch {
            print("[Debug] Lỗi khi load file \(filename): \(error)")
            return nil
        }
    }

    func renderPolygonsToImage(polygons: [MKPolygon], boundingMapRect: MKMapRect) -> UIImage {
        let maxImageSize: CGFloat = 1024.0
        let mapRectWidth = CGFloat(boundingMapRect.size.width)
        let mapRectHeight = CGFloat(boundingMapRect.size.height)
        let scaleX = maxImageSize / mapRectWidth
        let scaleY = maxImageSize / mapRectHeight
        let scale = min(scaleX, scaleY, 1.0)
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

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        drawVisiblePolygonsAsImageOverlay()
    }

    // Optional: tap để lấy địa chỉ
    @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
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
            self.showInfoView(address: address)
        }
    }
    func showInfoView(address: String) {
        view.subviews.filter { $0.tag == 9999 }.forEach { $0.removeFromSuperview() }
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
    }
}

//// Overlay ảnh
//class ImageOverlay: NSObject, MKOverlay {
//    var coordinate: CLLocationCoordinate2D
//    var boundingMapRect: MKMapRect
//    var image: UIImage
//    init(image: UIImage, boundingMapRect: MKMapRect, coordinate: CLLocationCoordinate2D) {
//        self.image = image
//        self.boundingMapRect = boundingMapRect
//        self.coordinate = coordinate
//    }
//}

//class ImageOverlayRenderer: MKOverlayRenderer {
//    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
//        guard let overlay = overlay as? ImageOverlay else { return }
//        let rect = self.rect(for: overlay.boundingMapRect)
//        context.saveGState()
//        context.setAlpha(1.0)
//        context.draw(overlay.image.cgImage!, in: rect)
//        context.restoreGState()
//    }
//}
