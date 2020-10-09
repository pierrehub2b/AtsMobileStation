//
//  DriverController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import Swifter

extension DriverController: Routeable {
    
    var name: String { return "driver" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        
        let token = request.headers["token"]
        if let atsClient = AtsClient.current, atsClient.token != token {
            return try! Router.Output(message: "Device already in use : \(atsClient.userAgent)", status: "-20").toHttpResponse()
        }
        
        guard let bodyString = String(bytes: request.body, encoding: .utf8) else {
            return .accepted
        }
            
        var bodyParameters: [String] = bodyString.components(separatedBy: "\n")
        let actionValue = bodyParameters.removeFirst()
            
        guard let action = DriverAction(rawValue: actionValue) else {
            return .accepted
        }
        
        switch action {
        case .start:
            guard let userAgent = request.headers["user-agent"] else {
                return .internalServerError
            }
            
            return startHandler(userAgent: userAgent)
            case .stop: return stopHandler()
            case .quit: return quitHandler()
            case .info: return fetchInfoHandler()
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
    
    private struct DriverInfoOutput: Content {
        let info: String
        let status = "0"
    }
    
    private struct DriverInfo: Content {
        let packageName: String
        let activity: String
        let system: String
        let label: String
        let icon = ""
        let version = ""
        let os = Device.current.os
    }
    
    private struct DriverStartOutput: Content {
        let os = Device.current.os
        let driverVersion = Device.current.driverVersion
        let systemName = Device.current.systemName

        let deviceWidth = Device.current.deviceWidth
        let deviceHeight = Device.current.deviceHeight
        let channelWidth = Device.current.channelWidth
        let channelHeight = Device.current.channelHeight
        let channelX = Device.current.channelX
        let channelY = Device.current.channelY
        
        let systemProperties = Device.Property.allCases.map { $0.rawValue }
        let systemButtons = Device.Button.allCases.map { $0.rawValue }
        
        let token = UUID().uuidString
        
        let status = "0"
        let screenCapturePort = Device.current.screenCapturePort
    }
    
    private func startHandler(userAgent: String) -> HttpResponse {
        continueExecution = true
             
        let output = DriverStartOutput()
        AtsClient.current = AtsClient(token: output.token, userAgent: userAgent, ipAddress: "")
        sendLogs(type: logType.STATUS, message: "** DEVICE LOCKED BY : \(AtsClient.current!.userAgent) **")
        
        return try! output.toHttpResponse()
    }
    
    private func stopHandler() -> HttpResponse {
        print(application)
        sendLogs(type: logType.INFO, message: "Terminate app")

        application?.terminate()
        continueExecution = false
        
        if !Device.current.isSimulator {
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        }
        
        AtsClient.current = nil
        sendLogs(type: logType.STATUS, message: "** DEVICE UNLOCKED **")

        return try! Router.Output(message: "stop ats driver").toHttpResponse()
    }
    
    private func quitHandler() -> HttpResponse {
        sendLogs(type: logType.INFO, message: "Terminate app")

        application?.terminate()
        continueExecution = false
        
        if !Device.current.isSimulator {
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        }
        
        return try! Router.Output(message: "close ats driver").toHttpResponse()
    }
    
    
    private func fetchInfoHandler() -> HttpResponse {
        guard let application = application else {
            return try! Router.Output(message: "").toHttpResponse()
        }
        
        let pattern = "'(.*?)'"
        guard let packageName = self.matchingStrings(input: String(application.description), regex: pattern).first?[1] else {
            return .internalServerError
        }
        
        let activity = getStateStringValue(rawValue: application.state.rawValue)
        let info = DriverInfo(packageName: packageName, activity: activity, system: Device.current.systemName, label: application.label)
        
        do {
            let jsonData = try JSONEncoder().encode(info)
            guard let json = String(data: jsonData, encoding: String.Encoding.utf8) else {
                return .internalServerError
            }
            
            return try! DriverInfoOutput(info: json).toHttpResponse()
        } catch {
            sendLogs(type: logType.ERROR, message: "Array convertIntoJSON - \(error.localizedDescription)")
            return try! DriverInfoOutput(info: "").toHttpResponse()
        }
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
