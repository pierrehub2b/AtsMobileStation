//
//  AppController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest

extension AppController: Routeable {
    
    var name: String {
        return "app"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        guard let firstParameter = parameters.first else {
            throw Router.RouterError.missingParameters
        }
        
        guard let action = AppAction(rawValue: firstParameter) else {
            return Router.Output(message: "missing app action type \(firstParameter)", status: "-42")
        }
        
        switch action {
        case .start:
            let appBundleIdentifier = try fetchAppBundleIdentifier(parameters)
            return start(appBundleIdentifier)
        case .stop:
            let appBundleIdentifier = try fetchAppBundleIdentifier(parameters)
            return stop(appBundleIdentifier)
        case .switch:
            let appBundleIdentifier = try fetchAppBundleIdentifier(parameters)
            return `switch`(appBundleIdentifier)
        case .info:
            return info()
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

    private func fetchAppBundleIdentifier(_ parameters: [String]) throws -> String {
        guard parameters.count > 1 else { throw Router.RouterError.missingParameters }
        
        let bundleIdentifier = parameters[1]
        return bundleIdentifier
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
    
    private func start(_ bundleIdentifier: String) -> Content {
        guard appsInstalled.contains(bundleIdentifier) || (appsInstalled.count == 0 && applications.count == 0) else {
            sendLogs(type: logType.ERROR, message: "Error on app launching: \(bundleIdentifier)")
            
            app = nil
            return Router.Output(message: "app package not found : \(bundleIdentifier)", status: "-51")
        }
        
        app = XCUIApplication.init(bundleIdentifier: bundleIdentifier)
        app.launch()
        
        activeChannelsCount += 1
        
        let label = app.label
        return StartOutput(label: label)
    }
    
    private func stop(_ bundleIdentifier: String) -> Content {
        app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        app.terminate()
        app = nil;
        
        activeChannelsCount -= 1
        if activeChannelsCount == 0 {
            AtsClient.current = nil
            sendLogs(type: logType.STATUS, message: "** DEVICE UNLOCKED **")
        }
        
        // sendLogs(type: logType.INFO, message: "Stop app \(parameters[1])")
        return Router.Output(message: "stop app \(bundleIdentifier)")
    }
    
    private func `switch`(_ bundleIdentifier: String) -> Content {
        app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        app.activate()
        
        //sendLogs(type: logType.INFO, message: "Switch app \(parameters[1])")
        return Router.Output(message: "switch app \(bundleIdentifier)")
    }
    
    private func info() -> Content {
        return InfoOutput()
    }
}
