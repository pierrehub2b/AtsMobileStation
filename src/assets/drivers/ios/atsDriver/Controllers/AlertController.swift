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
import CoreGraphics

extension AlertController: Routeable {
    
    var name: String {
        return "alert"
    }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let bodyString = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        var bodyParameters: [String] = bodyString.components(separatedBy: "\n")
        bodyParameters.removeFirst()
        let actionValue = bodyParameters.removeFirst()
        
        guard let action = AlertAction(rawValue: actionValue) else {
            return .internalServerError
        }
        
        switch action {
        case .tap:      return tapHandler(bodyParameters)
        case .input:    return inputHandler(bodyParameters)
        }
    }
    
}

final class AlertController {
    
    enum AlertAction: String {
        case tap
        case input
    }
    
    private func tapHandler(_ parameters: [String]) -> HttpResponse {
        guard application.state == .runningForeground else {
            return Output(message: "tap on element").toHttpResponse()
        }
        
        let vector = AlertController.getVector(parameters)

        if (application.alerts.allElementsBoundByIndex.count > 0) {
            let alert = application.alerts.firstMatch
            let point = CGPoint(x: vector.dx, y: vector.dy)
            if let button = alert.buttons.allElementsBoundByIndex.first(where: { $0.frame.contains(point) }) {
                button.tap()
            }
        }
        
        return Output(message: "tap on element").toHttpResponse()
    }
    
    private func inputHandler(_ parameters: [String]) -> HttpResponse {
        guard application.state == .runningForeground else {
            return Output(message: "tap on element").toHttpResponse()
        }
        
        let vector = AlertController.getVector(parameters)

        if (application.alerts.allElementsBoundByIndex.count > 0) {
            let alert = application.alerts.firstMatch
            let point = CGPoint(x: vector.dx, y: vector.dy)
            if let inputField = alert.textFields.allElementsBoundByIndex.first(where: { $0.frame.contains(point) }) {
                inputField.typeText("")
            }
        }
        
        return Output(message: "tap on element").toHttpResponse()
    }
    
    private static func getVector(_ parameters: [String]) -> CGVector {
        let offsetX = Double(parameters[0])!
        let offsetY = Double(parameters[1])!
        
        let values = parameters.last!.split(separator: ";")
        let x = Double(values[0])!
        let y = Double(values[1])!
        
        let width = Double(values[2])!
        let height = Double(values[3])!

        let screenScale = Double(UIScreen.main.scale)
        let vectorX = ((x + offsetX) + (width / 2)) / screenScale
        let vectorY = ((y + offsetY) + (height / 2)) / screenScale
        
        return CGVector(dx: vectorX, dy: vectorY)
    }
}
