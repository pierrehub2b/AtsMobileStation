//
//  Routeable.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation

protocol Routeable {
    
    var name: String { get }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any
}
