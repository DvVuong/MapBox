//
//  Enpoint.swift
//  MapBox
//
//  Created by VuongDv on 29/5/25.
//

import Foundation

enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
}

enum Endpoint {
  case properties
  case propertyDetail(id: String)
  case createProperty(data: Data)
  
  var path: String {
    switch self {
    case .properties:
      return "properties"
    case .propertyDetail(let id):
      return "properties/\(id)"
    case .createProperty:
      return "properties"
    }
  }
  
  var method: HTTPMethod {
    switch self {
    case .properties, .propertyDetail:
      return .get
    case .createProperty:
      return .post
    }
  }
  
  var url: URL {
    return URL(string: URLs.baseURL + path)!
  }
  
  var headers: [String: String]? {
    switch self {
    case .createProperty:
      return ["Content-Type": "application/json"]
    default:
      return ["accept": "application/json"]
    }
  }
  
  var body: Data? {
    switch self {
    case .createProperty(let data):
      return data
    default:
      return nil
    }
  }
}
