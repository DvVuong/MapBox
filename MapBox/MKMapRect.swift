//
//  MKMapRect.swift
//  MapBox
//
//  Created by VuongDv on 26/5/25.
//

import MapKit

extension MKMapRect {
  func contains(_ other: MKMapRect) -> Bool {
    return self.origin.x <= other.origin.x &&
    self.origin.y <= other.origin.y &&
    self.maxX >= other.maxX &&
    self.maxY >= other.maxY
  }
  
  var maxX: Double {
    return origin.x + size.width
  }
  
  var maxY: Double {
    return origin.y + size.height
  }
}
