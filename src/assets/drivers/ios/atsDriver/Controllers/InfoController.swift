//
//  InfoController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import UIKit

extension InfoController: Routeable {
    var name: String {
        return "info"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        return fetchInfo()
    }
}

final class InfoController {
        
    struct InfoOutput: Content {
        let os = "ios"
        let driverVersion: String = "1.1.0"
        let systemName = UIDevice.modelName.replacingOccurrences(of: "Simulator ", with: "") + " - " + UIDevice.current.systemVersion
        let deviceWidth: Double
        let deviceHeight: Double
        let channelWidth: Double
        let channelHeight: Double
        let channelX: Int = 0
        let channelY: Int = 0
        let message = "device capabilities"
        let status = "0"
        let id = UIDevice.current.identifierForVendor!.uuidString
        let model = UIDevice.modelName.replacingOccurrences(of: "Simulator ", with: "")
        let manufacturer = "Apple"
        let brand = "Apple"
        let version = UIDevice.current.systemVersion
        let bluetoothName = UIDevice.current.name
        let simulator = UIDevice.modelName.range(of: "Simulator", options: .caseInsensitive) != nil
        let applications: [Application]
    }
            
    func fetchInfo() -> InfoOutput {
        
        let testBundle = Bundle(for: atsDriver.self)
        if (!UIDevice.isSimulator) {
            appsInstalled = []
            if let url = testBundle.url(forResource: "Settings", withExtension: "plist"), let myDict = NSDictionary(contentsOf: url) as? [String:Any] {
                appsInstalled = myDict.filter { $0.key.contains("CFAppBundleID") }.map { $0.value } as! [String]
            }

            Application.setup()
        }
        
        let screenScale = UIScreen.main.scale
        let screenNativeBounds = XCUIScreen.main.screenshot().image.size
        let screenShotWidth = screenNativeBounds.width * screenScale
        let screenShotHeight = screenNativeBounds.height * screenScale
        
        channelWidth = Double(screenShotWidth)  //Double(screenSize.width)
        channelHeight = Double(screenShotHeight) //Double(screenSize.height)
        
        var ratio:Double = 1.0
        ratio = channelHeight / Double(screenNativeBounds.height);
        
        deviceWidth = Double(channelWidth / ratio)
        deviceHeight = Double(channelHeight / ratio)
        
        return InfoOutput(deviceWidth: deviceWidth, deviceHeight: deviceHeight, channelWidth: channelWidth, channelHeight: channelHeight, applications: applications)
    }
}
