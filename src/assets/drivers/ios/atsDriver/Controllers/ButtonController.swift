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
    }
}

final class ButtonController {
    
    private func transformAction(_ action:ButtonAction) -> XCUIDevice.Button? {
        switch action {
        case .home:
            return XCUIDevice.Button.home
        case .soundDown, .soundUp:
            return nil
        }
    }
    
    enum ButtonAction: String, CaseIterable {
        case home
        case soundUp
        case soundDown
    }
    
    private func pressButton(_ action:ButtonAction) -> Router.Output {
        if let deviceButton = transformAction(action) {
            XCUIDevice.shared.press(deviceButton)
            return Router.Output(message: "press \(action.rawValue) button")
        } else {
            return Router.Output(message: "press \(action.rawValue) button")
        }
    }
}
