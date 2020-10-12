//
//  InfoController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import UIKit
import Swifter

extension InfoController: Routeable {
    
    var name: String { return "info" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        return fetchInfo()
    }
}

final class InfoController {
    
    struct InfoOutput: Encodable {
        let os = "ios"
        let driverVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let buildNumber = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        let systemName = modelName + " - " + UIDevice.current.systemVersion
        let systemCountry = NSLocale.current.regionCode
        let deviceWidth: Double
        let deviceHeight: Double
        let channelWidth: Double
        let channelHeight: Double
        let channelX = 0
        let channelY = 0
        
        let message = "device capabilities"
        let status = "0"
        let id = UIDevice.current.identifierForVendor!.uuidString
        let model = modelName
        let manufacturer = "Apple"
        let brand = "Apple"
        let version = UIDevice.current.systemVersion
        let bluetoothName = UIDevice.current.name
        let simulator = Device.current.isSimulator
        let applications: [Application]
    }
    
    static let modelName = UIDevice.modelName.replacingOccurrences(of: "Simulator ", with: "")
    
    func fetchInfo() -> HttpResponse {
        let device = Device.current
        return InfoOutput(
            deviceWidth: device.deviceWidth,
            deviceHeight: device.deviceHeight,
            channelWidth: device.channelWidth,
            channelHeight: device.channelHeight,
            applications: Device.current.applications)
            .toHttpResponse()
    }
}
