//
//  PropertyController.swift
//  atsDriver
//
//  Created by Caipture on 23/07/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import Swifter

extension PropertyController: Routeable {
    
    var name: String { return "property-set" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let bodyString = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        var bodyParameters: [String] = bodyString.components(separatedBy: "\n")
        let actionValue = bodyParameters.removeFirst()
        
        guard let action = Device.Property(rawValue: actionValue) else {
            return .internalServerError
        }
        
        guard let propertyValue = bodyParameters.first else {
            return .internalServerError
        }
        
        switch action {
        case .airplaneModeEnabled:  return PropertyController.setAirplaneModeEnabled(propertyValue)
        case .bluetoothEnabled:     return PropertyController.setBluetoothModeEnabled(propertyValue)
        case .brightness:           return PropertyController.setBrightness(propertyValue)
        case .orientation:          return PropertyController.setOrientation(propertyValue)
        case .volume:               return PropertyController.setVolume(propertyValue)
        case .cellularDataEnabled:  return PropertyController.setCellularDataEnabled(propertyValue)
        case .wifiEnabled:          return PropertyController.setWifiEnabled(propertyValue)
        }
    }
}

final class PropertyController {
    
    private static func setAirplaneModeEnabled(_ value:String) -> HttpResponse {
        guard let _ = booleanFromString(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        return Output(message: "property not available").toHttpResponse()
    }
    
    private static func setWifiEnabled(_ value:String) -> HttpResponse {
        guard let _ = booleanFromString(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        return Output(message: "property not available").toHttpResponse()
        
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
    
    private static func setCellularDataEnabled(_ value:String) -> HttpResponse {
        guard let enabled = booleanFromString(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        #if targetEnvironment(simulator)
        
        return try Output.Output(message: "property not available").toHttpResponse()
        
        #else
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[4].tap()
        
        do {
            try enableSwitch(enabled, atIndex: 0)
            return Output(message: "property set").toHttpResponse()
        } catch {
            return Output(message: "property set").toHttpResponse()
        }
        
        #endif
    }
    
    
    private static func setBluetoothModeEnabled(_ value:String) -> HttpResponse {
        guard let enabled = booleanFromString(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        #if targetEnvironment(simulator)
        return try Output.Output(message: "property not available").toHttpResponse()
        #else
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[3].tap()
        
        do {
            try enableSwitch(enabled, atIndex: 1)
            application.launch()
            return Output(message: "property set").toHttpResponse()
        } catch {
            return .internalServerError
        }
        
        #endif
    }
    
    
    private static func setOrientation(_ value:String) -> HttpResponse {
        guard let intValue = Int(value), let deviceOrientation = UIDeviceOrientation(rawValue: intValue) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        XCUIDevice.shared.orientation = deviceOrientation
        
        return Output(message: "property set").toHttpResponse()
    }
    
    private static func setBrightness(_ value:String) -> HttpResponse {
        guard let intValue = Int(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        #if targetEnvironment(simulator)
        
        return try Output(message: "property not available").toHttpResponse()
        
        #else
        
        let floatValue = CGFloat(intValue) / 100.0
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[12].tap()
        settingsApp.sliders.allElementsBoundByIndex.first!.adjust(toNormalizedSliderPosition: floatValue)
        
        return Output(message: "property set").toHttpResponse()
        
        #endif
    }
    
    private static func setVolume(_ value:String) -> HttpResponse {
        guard let intValue = Int(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        #if targetEnvironment(simulator)
        
        return try Output(message: "property not available").toHttpResponse()
        
        #else
        
        let floatValue = CGFloat(intValue) / 100.0
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[7].tap()
        settingsApp.sliders.allElementsBoundByIndex.first!.adjust(toNormalizedSliderPosition: floatValue)
        
        return Output(message: "property set").toHttpResponse()
        
        #endif
    }
    
    private static let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    
    private enum EnableSwitchError: Error {
        case elementNotFound
        case badElementValue
    }
    
    private static func enableSwitch(_ enabled:Bool, atIndex index:Int) throws {
        // let allSwitches = settingsApp.switches.count
        print(settingsApp.description)
        // print(allSwitches)
        
        // for index in 0...allSwitches - 1 {
        // print("AAAAAAAAAAAAAAAAAH")
        // print(settingsApp.switches.element(boundBy: index).debugDescription)
        // }
        
        
        /*guard !allSwitches.isEmpty else {
         throw EnableSwitchError.elementNotFound
         }*/
        
        let element = settingsApp.switches.element(boundBy: 0)
        
        guard let elementValue = element.value as? String, let boolValue = Bool(elementValue) else {
            throw EnableSwitchError.badElementValue
        }
        
        if enabled != boolValue {
            element.tap()
        }
    }
    
    private static func booleanFromString(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "1", "on", "true":     return true
        case "0", "off", "false":   return false
        default:                    return nil
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
