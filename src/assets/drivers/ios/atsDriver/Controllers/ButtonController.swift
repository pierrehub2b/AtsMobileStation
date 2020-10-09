//
//  ButtonController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import Swifter

extension ButtonController: Routeable {
    
    var name: String { return "sysbutton" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let buttonName = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        guard let action = Device.Button(rawValue: buttonName) else {
            return .internalServerError
        }
        
        switch action {
        case .lock:
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
            return try! Router.Output(message: "press \(action.rawValue) button").toHttpResponse()
        default:
            return try! pressButton(action)
        }
    }
}

final class ButtonController {
    
    enum ButtonControllerError: Error {
        case unknowButton
    }
    
    private func pressButton(_ action:Device.Button) throws -> HttpResponse {
        if let deviceButton = transformAction(action) {
            XCUIDevice.shared.press(deviceButton)
            return try Router.Output(message: "press \(action.rawValue) button").toHttpResponse()
        } else {
            return try Router.Output(message: "press \(action.rawValue) button").toHttpResponse()
        }
    }
    
    private func transformAction(_ action:Device.Button) -> XCUIDevice.Button? {
        switch action {
        case .home:
            return XCUIDevice.Button.home
        default:
            return nil
        /* case .soundDown:
            #if TARGET_OS_SIMULATOR
            return nil
            #else
            return XCUIDevice.Button.soundDown
            #endif
        case .soundUp:
            #if TARGET_OS_SIMULATOR
            return nil
            #else
            return XCUIDevice.Button.soundUp
            #endif */
        }
    }
}
