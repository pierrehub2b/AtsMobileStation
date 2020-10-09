//
//  Content.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import Swifter

protocol Content: Encodable {
    func toJSONData() -> Data?
    func toJSON() -> [String: Any]?
}

extension Content {
    func toJSONData() -> Data? { try? JSONEncoder().encode(self) }
    
    func toJSON() -> [String: Any]? {
        guard let data = self.toJSONData() else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    func toHttpResponseBody() throws -> HttpResponseBody {
        return .data(toJSONData()!, contentType: "application/json")
    }
    
    func toHttpResponse() throws -> HttpResponse {
        return try .ok(toHttpResponseBody())
    }
}
