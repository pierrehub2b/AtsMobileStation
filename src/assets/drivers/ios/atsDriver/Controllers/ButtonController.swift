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
        guard let firstParameter = parameters.first, let action = ButtonAction(rawValue: firstParameter) else {
            throw Router.RouterError.missingParameters
        }
        
        return pressButton(action)
        
        
        /* switch action {
        case .home:
            return pressHomeButton()
        case .orientation:
            return switchOrientation()
        default:
            return Router.Output(message: "unknow button \(action.rawValue)", status: "-42")
        } */
    }
}

final class ButtonController {
    
    private func transformAction(_ action:ButtonAction) -> XCUIDevice.Button? {
        switch action {
        case .home:
            return XCUIDevice.Button.home
        default:
            return nil
        }
    }
    
    private enum ButtonAction: String {
        case home
        case soundup
        case sounddown
        /* case silentswitch
        case lock
        case enter
        case `return`
        case orientation */
    }
    
    private func pressButton(_ action:ButtonAction) -> Router.Output {
        if let deviceButton = transformAction(action) {
            XCUIDevice.shared.press(deviceButton)
        }
        
        return Router.Output(message: "press home button")
    }
    
    /* private func pressHomeButton() -> Router.Output {
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
    } */
}
