//
//  DriverController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest

extension DriverController: Routeable {    
    var name: String {
        return "driver"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        guard let firstParameter = parameters.first else {
            throw Router.RouterError.missingParameters
        }
        
        guard let action = DriverAction(rawValue: firstParameter) else {
            return Router.Output(message: "missing app action type \(firstParameter)", status: "-42")
        }
        
        if let atsClient = AtsClient.current, atsClient.token != token {
            return Router.Output(message: "Device already in use : \(atsClient.userAgent)", status: "-20")
        }
        
        switch action {
        case .start:
            let result = start()
            AtsClient.current = AtsClient(token: result.token, userAgent: userAgent!, ipAddress: "")
            sendLogs(type: logType.STATUS, message: "** DEVICE LOCKED BY : \(AtsClient.current!.userAgent) **")
            return result
        case .stop:
            let result = stop()
            AtsClient.current = nil
            activeChannelsCount = 0
            sendLogs(type: logType.STATUS, message: "** DEVICE UNLOCKED **")
            return result
        case .quit:
            return quit()
        case .info:
            return try fetchInfo()
        }
    }
}

final class DriverController {
    
    private enum DriverAction: String {
        case start
        case stop
        case quit
        case info
    }
    
    struct DriverInfoOutput: Content {
        let info: String
        let status = "0"
    }
    
    private struct DriverStartOutput: Content {
        let os = "ios"
        let driverVersion = "1.1.0"
        let channelX = 0
        let channelY = 0
        let status = "0"
        let screenCapturePort = udpPort
        let systemName = model + " - " + osVersion
        let deviceWidth: Double
        let deviceHeight: Double
        let channelWidth: Double
        let channelHeight: Double
        let token: String
    }
    
    private func start() -> DriverStartOutput {
        continueExecution = true
        
        // Application size
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
        
        return DriverStartOutput(deviceWidth: deviceWidth, deviceHeight: deviceHeight, channelWidth: channelWidth, channelHeight: channelHeight, token: UUID().uuidString)
    }
    
    private func stop() -> Content {
        if (app != nil) {
            app.terminate()
        }
        
        //sendLogs(type: logType.INFO, message: "Terminate app")
        if !UIDevice.isSimulator {
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        }

        return Router.Output(message: "stop ats driver")
    }
    
    private func quit() -> Content {
        if (app != nil) {
            app.terminate()
        }
        
        //sendLogs(type: logType.INFO, message: "Terminate app")
        if !UIDevice.isSimulator {
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        }
        continueExecution = false

        return Router.Output(message: "close ats driver")
    }
    
    private struct DriverInfo: Content {
        let packageName: String
        let activity: String
        let system: String
        let label = app.label
        let icon = ""
        let version = ""
        let os = "ios"
    }
    
    private func fetchInfo() throws -> Content {
        guard let app = app else {
            return DriverInfoOutput(info: "")
        }
        
        let pattern = "'(.*?)'"
        guard let packageName = self.matchingStrings(input: String(app.description), regex: pattern).first?[1] else { throw Router.RouterError.driverError }
        
        let activity = getStateStringValue(rawValue: app.state.rawValue)

        let osVersion = UIDevice.current.systemVersion
        let model = UIDevice.modelName.replacingOccurrences(of: "Simulator ", with: "")
        let system = model + " " + osVersion
        
        let info = DriverInfo(packageName: packageName, activity: activity, system: system)
        
        do {
            let jsonData = try JSONEncoder().encode(info)

            guard let json = String(data: jsonData, encoding: String.Encoding.utf8) else {
                return DriverInfoOutput(info: "no values")
            }
            
            return DriverInfoOutput(info: json)
        } catch {
            sendLogs(type: logType.ERROR, message: "Array convertIntoJSON - \(error.localizedDescription)")
        }
        
        return DriverInfoOutput(info: "")
    }
}

extension DriverController {
    
    func matchingStrings(input: String, regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = input as NSString
        let results  = regex.matches(in: input, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound ? nsString.substring(with: result.range(at: $0)) : ""
            }
        }
    }
}
