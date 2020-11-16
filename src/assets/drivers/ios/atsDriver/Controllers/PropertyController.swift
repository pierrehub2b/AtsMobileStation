//Licensed to the Apache Software Foundation (ASF) under one
//or more contributor license agreements.  See the NOTICE file
//distributed with this work for additional information
//    regarding copyright ownership.  The ASF licenses this file
//to you under the Apache License, Version 2.0 (the
//"License"); you may not use this file except in compliance
//with the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing,
//software distributed under the License is distributed on an
//"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//KIND, either express or implied.  See the License for the
//specific language governing permissions and limitations
//under the License.

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
        // case .airplaneModeEnabled:  return setAirplaneModeEnabled(propertyValue)
        case .bluetoothEnabled:     return setBluetoothModeEnabled(propertyValue)
        // case .brightness:           return setBrightness(propertyValue)
        case .orientation:          return PropertyController.setOrientation(propertyValue)
        // case .volume:               return setVolume(propertyValue)
        case .cellularDataEnabled:  return setCellularDataEnabled(propertyValue)
        // case .wifiEnabled:          return setWifiEnabled(propertyValue)
        }
    }
}

final class PropertyController {
    
    private let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    
    var wiFiIndex: Int?
    var airplaneModeIndex: Int!
    var bluetoothIndex: Int!
    var cellularDataIndex: Int!
    
    private func setAirplaneModeEnabled(_ value:String) -> HttpResponse {
        return Output(message: "property not available").toHttpResponse()
    }
    
    private func setWifiEnabled(_ value:String) -> HttpResponse {
        return Output(message: "property not available").toHttpResponse()
    }
    
    private func setCellularDataEnabled(_ value:String) -> HttpResponse {
        #if targetEnvironment(simulator)
        return Output(message: "property not available").toHttpResponse()
        #else
        guard let enabled = PropertyController.booleanFromString(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        settingsApp.launch()
        
        do {
            try fetchWiFiCellIndex()
            let cell = settingsApp.cells.allElementsBoundByIndex[cellularDataIndex]
            if cell.isEnabled {
                cell.tap()
                try enableSwitch(enabled, atIndex: 0)
                application.activate()
                return Output(message: "property set").toHttpResponse()
            } else {
                application.activate()
                return Output(message: "property not enabled", status: "-11").toHttpResponse()
            }
        } catch is EnableSwitchError {
            application.activate()
            return Output(message: "property set").toHttpResponse()
        } catch PropertyControllerError.wiFiIndexNotFound {
            application.activate()
            return Output(message: "property set").toHttpResponse()
        } catch let error {
            application.activate()
            return Output(message: error.localizedDescription, status: "-11").toHttpResponse()
        }
        #endif
    }
    
    
    private func setBluetoothModeEnabled(_ value:String) -> HttpResponse {
        #if targetEnvironment(simulator)
        return Output(message: "property not available").toHttpResponse()
        #else
        guard let enabled = PropertyController.booleanFromString(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        settingsApp.launch()
        
        do {
            try fetchWiFiCellIndex()
            settingsApp.cells.allElementsBoundByIndex[bluetoothIndex].tap()
            try enableSwitch(enabled, atIndex: 0)
            application.activate()
            
            return Output(message: "property set").toHttpResponse()
        } catch is EnableSwitchError {
            application.activate()
            return Output(message: "property set").toHttpResponse()
        } catch PropertyControllerError.wiFiIndexNotFound {
            application.activate()
            return Output(message: "property set").toHttpResponse()
        } catch let error {
            application.activate()
            return Output(message: error.localizedDescription, status: "-11").toHttpResponse()
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
    
    private func setBrightness(_ value:String) -> HttpResponse {
        #if targetEnvironment(simulator)
        return Output(message: "property not available").toHttpResponse()
        #else
        guard let intValue = Int(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        let floatValue = CGFloat(intValue) / 100.0
        
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[12].tap()
        settingsApp.sliders.allElementsBoundByIndex.first!.adjust(toNormalizedSliderPosition: floatValue)
        
        return Output(message: "property set").toHttpResponse()
        #endif
    }
    
    private func setVolume(_ value:String) -> HttpResponse {
        #if targetEnvironment(simulator)
        return Output(message: "property not available").toHttpResponse()
        #else
        guard let intValue = Int(value) else {
            return Output(message: "bad value").toHttpResponse()
        }
        
        let floatValue = CGFloat(intValue) / 100.0
                
        settingsApp.launch()
        settingsApp.cells.allElementsBoundByIndex[7].tap()
        settingsApp.sliders.allElementsBoundByIndex.first!.adjust(toNormalizedSliderPosition: floatValue)
             
        return Output(message: "property set").toHttpResponse()
        #endif
    }
        
    private enum EnableSwitchError: Error {
        case elementNotFound
        case badElementValue
    }
    
    private func enableSwitch(_ enabled:Bool, atIndex index:Int) throws {
        let element = settingsApp.switches.allElementsBoundByIndex[index]
                
        if let value = element.value as? String, let boolValue = PropertyController.booleanFromString(value), enabled != boolValue {
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
    
    private enum PropertyControllerError: Error {
        case wiFiIndexNotFound
    }
    
    private func fetchWiFiCellIndex() throws  {
        guard self.wiFiIndex == nil else { return }
        
        settingsApp.cells.allElementsBoundByIndex.enumerated().forEach { (index, element) in
            if element.label == "Wi-Fi" {
                self.wiFiIndex = index
                return
            }
        }
        
        guard let wiFiIndex = self.wiFiIndex else {
            throw PropertyControllerError.wiFiIndexNotFound
        }
        
        self.airplaneModeIndex = wiFiIndex - 1
        self.bluetoothIndex = wiFiIndex + 1
        self.cellularDataIndex = wiFiIndex + 2
    }
}
