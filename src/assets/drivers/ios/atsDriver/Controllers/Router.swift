//
//  Router.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest

final class Router {
    
    enum RouterError: Error {
        case badRoute
        case missingParameters
        case driverError
    }
    
    struct Output: Content {
        let message: String
        var status: String = "0"
    }
    
    static let main = Router()
    
    private var controllers: [Routeable] = []
    
    init() {        
        register(ElementController())
        register(DriverController())
        register(AppController())
        register(CaptureController())
        register(InfoController())
        register(ScreenshotController())
        register(ButtonController())
    }
    
    private func register(_ controller: Routeable) {
        controllers.append(controller)
    }
    
    func route(_ path: String, parameters: [String], token: String? = nil) throws -> Any {
        guard let controller = controllers.first(where: { $0.name == path }) else {
            throw RouterError.badRoute
        }
        
        if controller is CaptureController == false {
            asChanged = true
        }
        
        return try controller.handleParameters(parameters, token: token)
    }
}
