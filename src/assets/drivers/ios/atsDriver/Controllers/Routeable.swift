//
//  Routeable.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import Swifter

protocol Routeable {
    
    var name: String { get }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse
}
