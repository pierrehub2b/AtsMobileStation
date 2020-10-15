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

extension AppController: Routeable {
    
    var name: String { return "app" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let bodyString = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        var bodyParameters: [String] = bodyString.components(separatedBy: "\n")
        let actionValue = bodyParameters.removeFirst()
        
        guard let action = AppAction(rawValue: actionValue) else {
            return Output(message: "missing app action type \(actionValue)", status: "-42").toHttpResponse()
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
    
    private struct StartOutput: Encodable {
        let status: String = "0"
        let label: String
        let icon: String = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="
        let version: String = "0.0.0"
    }
    
    private struct InfoOutput: Encodable {
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
            sendLogs(type: .error, message: "Error on app launching: \(bundleIdentifier)")
            application = nil
            return Output(message: "app package not found : \(bundleIdentifier)", status: "-51").toHttpResponse()
        }
        
        sendLogs(type: .info, message: "Launching app \(bundleIdentifier)")
        
        application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.launch()
                  
        return StartOutput(label: application.label).toHttpResponse()
    }
    
    private func stopHandler(_ parameters: [String]) -> HttpResponse {
        guard let bundleIdentifier = parameters.first else {
            return .internalServerError
        }
        
        sendLogs(type: .info, message: "Stop app \(bundleIdentifier)")
        
        application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.terminate()
        application = nil
        
        return Output(message: "stop app \(bundleIdentifier)").toHttpResponse()
    }
    
    private func switchHandler(_ parameters: [String]) -> HttpResponse {
        guard let bundleIdentifier = parameters.first else {
            return .internalServerError
        }
        
        sendLogs(type: .info, message: "Switch app \(bundleIdentifier)")
        
        application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.activate()
        
        return Output(message: "switch app \(bundleIdentifier)").toHttpResponse()
    }
    
    private func fetchInfoHandler() -> HttpResponse {
        return InfoOutput().toHttpResponse()
    }
}
