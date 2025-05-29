//
//  APIManager.swift
//  MapBox
//
//  Created by VuongDv on 29/5/25.
//

import Foundation

class APIManager {
  static let shared = APIManager()
  
  private let apiKey = "799957b009ff47b28826d96359b946cb"
  
  private init() {}
  
  func fetchData<T: Codable>(from endpoint: Endpoint) async throws -> T {
    var request = URLRequest(url: endpoint.url)
    request.httpMethod = endpoint.method.rawValue
    // Thêm headers nếu có
    endpoint.headers?.forEach { key, value in
      request.addValue(value, forHTTPHeaderField: key)
    }
    
    // Thêm body nếu có
    if let body = endpoint.body {
      request.httpBody = body
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    // Thêm X-Api-Key nếu chưa có
    if request.value(forHTTPHeaderField: "X-Api-Key") == nil {
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // Kiểm tra mã phản hồi HTTP
    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }
    
    guard (200...299).contains(httpResponse.statusCode) else {
        // Gỡ lỗi dễ hơn bằng cách in mã lỗi và nội dung server trả về
        let responseBody = String(data: data, encoding: .utf8) ?? "No body"
        print("[Debug] HTTP Error: \(httpResponse.statusCode)")
        print("[Debug] Response Body: \(responseBody)")
        throw URLError(.badServerResponse)
    }
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    return try decoder.decode(T.self, from: data)
  }
}
