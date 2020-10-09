//
//  AppController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import Swifter

extension AppController: Routeable {
    
    var name: String { return "app" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let bodyString = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        var bodyParameters: [String] = bodyString.components(separatedBy: "\n")
        let actionValue = bodyParameters.removeFirst()
        
        guard let action = AppAction(rawValue: actionValue) else {
            return try! Router.Output(message: "missing app action type \(actionValue)", status: "-42").toHttpResponse()
        }
        
        switch action {
        case .start:    return self.startHandler(bodyParameters)
        case .stop:     return self.stopHandler(bodyParameters)
        case .switch:   return self.switchHandler(bodyParameters)
        case .info:     return self.fetchInfoHandler()
        }
    }
}

final class AppController {
    
    private enum AppAction: String {
        case start
        case stop
        case info
        case `switch`
    }
    
    private struct StartOutput: Content {
        let status: String = "0"
        let label: String
        let icon: String = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="
        let version: String = "0.0.0"
    }
    
    private struct InfoOutput: Content {
        struct Info: Encodable {
            let os = "ios"
            let icon = ""
            let label = ""
        }
        
        let code = "0"
        let info = Info()
    }
    
    private func startHandler(_ parameters: [String]) -> HttpResponse {
        guard let bundleIdentifier = parameters.first else {
            return .internalServerError
        }
        
        guard Device.current.applications.map({ $0.packageName }).contains(bundleIdentifier) else {
            sendLogs(type: logType.ERROR, message: "Error on app launching: \(bundleIdentifier)")
            application = nil
            return try! Router.Output(message: "app package not found : \(bundleIdentifier)", status: "-51").toHttpResponse()
        }
        
        sendLogs(type: logType.INFO, message: "Launching app \(bundleIdentifier)")
        
        application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.launch()
                  
        return try! StartOutput(label: application.label).toHttpResponse()
    }
    
    private func stopHandler(_ parameters: [String]) -> HttpResponse {
        guard let bundleIdentifier = parameters.first else {
            return .internalServerError
        }
        
        sendLogs(type: logType.INFO, message: "Stop app \(bundleIdentifier)")
        
        application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.terminate()
        application = nil
        
        return try! Router.Output(message: "stop app \(bundleIdentifier)").toHttpResponse()
    }
    
    private func switchHandler(_ parameters: [String]) -> HttpResponse {
        guard let bundleIdentifier = parameters.first else {
            return .internalServerError
        }
        
        sendLogs(type: logType.INFO, message: "Switch app \(bundleIdentifier)")
        
        application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.activate()
        
        return try! Router.Output(message: "switch app \(bundleIdentifier)").toHttpResponse()
    }
    
    private func fetchInfoHandler() -> HttpResponse {
        return try! InfoOutput().toHttpResponse()
    }
}
