//
//  ButtonController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest

extension ButtonController: Routeable {
    
    var name: String {
        return "sysbutton"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        guard let firstParameter = parameters.first else {
            throw Router.RouterError.missingParameters
        }
        
        guard let action = ButtonAction(rawValue: firstParameter) else {
            throw ButtonControllerError.unknowButton
        }
        
        if action == .lock {
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
            return Router.Output(message: "press \(action.rawValue) button")
        } else {
            return pressButton(action)
        }
    }
}

final class ButtonController {
    
    enum ButtonControllerError: Error {
        case unknowButton
    }
    
    enum ButtonAction: String, CaseIterable {
        case home
        case soundUp
        case soundDown
        case lock
    }
        
    private func pressButton(_ action:ButtonAction) -> Router.Output {
        if let deviceButton = transformAction(action) {
            XCUIDevice.shared.press(deviceButton)
            return Router.Output(message: "press \(action.rawValue) button")
        } else {
            return Router.Output(message: "press \(action.rawValue) button")
        }
    }
    
    private func transformAction(_ action:ButtonAction) -> XCUIDevice.Button? {
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
