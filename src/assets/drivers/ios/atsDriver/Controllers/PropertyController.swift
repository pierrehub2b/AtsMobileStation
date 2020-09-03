//
//  PropertyController.swift
//  atsDriver
//
//  Created by Caipture on 23/07/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest

extension PropertyController: Routeable {
    var name: String {
        return "property-set"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        guard let propertyName = parameters.first, let property = PropertyActionName(rawValue: propertyName), let propertyValue = parameters.last else {
            throw Router.RouterError.missingParameters
        }
        
        switch property {
        case .airplaneModeEnabled:
            return PropertyController.setAirplaneModeEnabled(propertyValue)
        case .bluetoothEnabled:
            return PropertyController.setBluetoothModeEnabled(propertyValue)
        case .brightness:
            return PropertyController.setBrightness(propertyValue)
        case .orientation:
            return PropertyController.setOrientation(propertyValue)
        case .volume:
            return PropertyController.setVolume(propertyValue)
        case .cellularDataEnabled:
            return PropertyController.setCellularDataEnabled(propertyValue)
        case .wifiEnabled:
            return PropertyController.setWifiEnabled(propertyValue)
        }
    }
}

final class PropertyController {
    
    enum PropertyActionName: String, CaseIterable {
        case airplaneModeEnabled
        case wifiEnabled
        case cellularDataEnabled
        case bluetoothEnabled
        case orientation
        case brightness
        case volume
    }
    
    private static func setAirplaneModeEnabled(_ value:String) -> Router.Output {
        guard let _ = Bool(value) else {
            return Router.Output(message: "bad value")
        }
        
        return Router.Output(message: "property not available")
    }
    
    private static func setWifiEnabled(_ value:String) -> Router.Output {
        guard let _ = Bool(value) else {
            return Router.Output(message: "bad value")
        }
        
        return Router.Output(message: "property not available")
        
        /*
         settingsApp.launch()
         settingsApp.cells.allElementsBoundByIndex[2].tap()
         
         do {
         try enableSwitch(enabled, atIndex: 0)
         return Router.Output(message: "property set")
         } catch {
         return Router.Output(message: "property set")
         }
         */
    }
    
    private static func setCellularDataEnabled(_ value:String) -> Router.Output {
        guard let enabled = Bool(value) else {
            return Router.Output(message: "bad value")
        }
        
        #if targetEnvironment(simulator)
        
        return Router.Output(message: "property not available")
        
        #else
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[4].tap()
        
        do {
            try enableSwitch(enabled, atIndex: 0)
            return Router.Output(message: "property set")
        } catch {
            return Router.Output(message: "property set")
        }
        
        #endif
    }
    

    
    private static func setBluetoothModeEnabled(_ value:String) -> Router.Output {
        guard let enabled = Bool(value) else {
            return Router.Output(message: "bad value")
        }
        
        #if targetEnvironment(simulator)
        
        return Router.Output(message: "property not available")
        
        #else
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[3].tap()
        
        do {
            try enableSwitch(enabled, atIndex: 0)
            return Router.Output(message: "property set")
        } catch {
            return Router.Output(message: "property set")
        }
        
        #endif
    }
    
    
    private static func setOrientation(_ value:String) -> Router.Output {
        guard let intValue = Int(value), let deviceOrientation = UIDeviceOrientation(rawValue: intValue) else {
            return Router.Output(message: "bad value")
        }
        
        XCUIDevice.shared.orientation = deviceOrientation
        
        return Router.Output(message: "property set")
    }
    
    private static func setBrightness(_ value:String) -> Router.Output {
        guard let intValue = Int(value) else {
            return Router.Output(message: "bad value")
        }
        
        #if targetEnvironment(simulator)
        
        return Router.Output(message: "property not available")

        #else
        
        let floatValue = CGFloat(intValue) / 100.0
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[12].tap()
        settingsApp.sliders.allElementsBoundByIndex.first!.adjust(toNormalizedSliderPosition: floatValue)
        
        return Router.Output(message: "property set")
        
        #endif
    }
    
    private static func setVolume(_ value:String) -> Router.Output {
        guard let intValue = Int(value) else {
            return Router.Output(message: "bad value")
        }
        
        #if targetEnvironment(simulator)

        return Router.Output(message: "property not available")
        
        #else
        
        let floatValue = CGFloat(intValue) / 100.0
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[7].tap()
        settingsApp.sliders.allElementsBoundByIndex.first!.adjust(toNormalizedSliderPosition: floatValue)
        
        return Router.Output(message: "property set")
        
        #endif
    }
    
    private static let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    
    
    private enum EnableSwitchError: Error {
        case elementNotFound
        case badElementValue
    }
    
    private static func enableSwitch(_ enabled:Bool, atIndex index:Int) throws {
        let allSwitches = settingsApp.switches.allElementsBoundByIndex
        guard !allSwitches.isEmpty else {
            throw EnableSwitchError.elementNotFound
        }
        
        let element = allSwitches[index]
        
        guard let elementValue = element.value as? String, let boolValue = Bool(elementValue) else {
            throw EnableSwitchError.badElementValue
        }
        
        if enabled != boolValue {
            element.tap()
        }
    }
    
    /*
    private static func setNightModeEnabled(_ value:String) -> Router.Output {
        guard let enabled = Bool(value) else {
            return Router.Output(message: "bad value")
        }
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[12].tap()
        
        return Router.Output(message: "bad value")
    }
    */
}
