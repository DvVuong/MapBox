//
//// MARK: Dùng GeoJson để hiện thị lên MapKit

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

//    let overlays = GeoJsonLoader.loadGeoJSONFiles(from: "AlaskaTilePython3")
//    mapView.addOverlays(overlays)
//
//    // Zoom to Alaska
//    if let first = overlays.first {
//      mapView.setVisibleMapRect(first.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)
//    }
//    
//    let region = mapView.region
//    let center = region.center
//    let span = region.span
  }

  // MARK: - MKMapViewDelegate
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
