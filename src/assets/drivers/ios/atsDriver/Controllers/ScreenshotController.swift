//
//  ScreenshotController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import Swifter

extension ScreenshotController: Routeable {
    
    var name: String { return "screenshot" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        return screenshot()
    }
}

final class ScreenshotController {
        
    func screenshot() -> HttpResponse {
        guard let screenshotData = XCUIScreen.main.screenshot().image.pngData() else {
            return .internalServerError
        }
        
        return .ok(.data(screenshotData, contentType: "image/png"))
    }
}
