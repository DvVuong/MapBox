//
//  PropertyLandRespone.swift
//  MapBox
//
//  Created by VuongDv on 29/5/25.
//

import Foundation
import CoreLocation

struct PropertyLandRespone: Codable {
  let id: String?
  let formattedAddress: String?
  let addressLine1: String?
  let addressLine2: String?
  let city: String?
  let state: String?
  let zipCode: String?
  let county: String?
  let latitude: Double?
  let longitude: Double?
  let propertyType: String?
  let bedrooms: Int?
  let bathrooms: Double?
  let squareFootage: Int?
  let lotSize: Int?
  let yearBuilt: Int?
  let assessorID: String?
  let legalDescription: String?
  let subdivision: String?
  let zoning: String?
  let lastSaleDate: String?
  let lastSalePrice: Int?
  let hoa: HOA?
  let features: Features?
  let taxAssessments: [String: TaxAssessment]?
  let propertyTaxes: [String: PropertyTax]?
  let history: [String: SaleHistory]?
  let owner: Owner?
  let ownerOccupied: Bool?
  
  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude ?? 0, longitude: longitude ?? 0)
  }
}

struct HOA: Codable {
  let fee: Int?
}

struct Features: Codable {
  let architectureType: String?
  let cooling: Bool?
  let coolingType: String?
  let exteriorType: String?
  let fireplace: Bool?
  let fireplaceType: String?
  let floorCount: Int?
  let foundationType: String?
  let garage: Bool?
  let garageSpaces: Int?
  let garageType: String?
  let heating: Bool?
  let heatingType: String?
  let pool: Bool?
  let poolType: String?
  let roofType: String?
  let roomCount: Int?
  let unitCount: Int?
  let viewType: String?
}

struct TaxAssessment: Codable {
  let year: Int?
  let value: Int?
  let land: Int?
  let improvements: Int?
}

struct PropertyTax: Codable {
  let year: Int?
  let total: Int?
}

struct SaleHistory: Codable {
  let event: String?
  let date: String?
  let price: Int?
}

struct Owner: Codable {
  let names: [String]?
  let type: String?
  let mailingAddress: MailingAddress?
}

struct MailingAddress: Codable {
  let id: String?
  let formattedAddress: String?
  let addressLine1: String?
  let addressLine2: String?
  let city: String?
  let state: String?
  let zipCode: String?
}
