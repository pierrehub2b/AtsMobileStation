//
//  ScreenshotController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest

extension ScreenshotController: Routeable {
    var name: String {
        return "screenshot"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        return try screenshot()
    }
}

final class ScreenshotController {
        
    func screenshot() throws -> Data {
        return XCUIScreen.main.screenshot().image.pngData()!
    }
}
