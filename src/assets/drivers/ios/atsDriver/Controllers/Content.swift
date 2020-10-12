//
//  Content.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import Swifter

extension Encodable {
    
    func toJSONData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
        
    func toHttpResponseBody() throws -> HttpResponseBody {
        let jsonData = try toJSONData()
        return .data(jsonData, contentType: "application/json")
    }
    
    func toHttpResponse() -> HttpResponse {
        do {
            return try .ok(toHttpResponseBody())
        } catch {
            return .internalServerError
        }
    }
}
