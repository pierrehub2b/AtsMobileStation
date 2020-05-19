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
        return "button"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        guard let firstParameter = parameters.first, let action = ButtonAction(rawValue: firstParameter) else {
            throw Router.RouterError.missingParameters
        }
        
        switch action {
        case .home:
            return pressHomeButton()
        case .orientation:
            return switchOrientation()
        default:
            return Router.Output(message: "unknow button \(action.rawValue)", status: "-42")
        }
    }
}

final class ButtonController {
    
    private enum ButtonAction: String {
        case home
        case soundup
        case sounddown
        case silentswitch
        case lock
        case enter
        case `return`
        case orientation
    }
    
    private func pressHomeButton() -> Router.Output {
        XCUIDevice.shared.press(.home)
        return Router.Output(message: "press home button")
    }
    
    private func switchOrientation() -> Router.Output {
        if (XCUIDevice.shared.orientation == .landscapeLeft) {
            XCUIDevice.shared.orientation = .portrait
            return Router.Output(message: "orientation to portrait mode")
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
            return Router.Output(message: "orientation to landscape mode")
        }
    }
}
