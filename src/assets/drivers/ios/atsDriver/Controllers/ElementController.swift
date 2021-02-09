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
import CoreGraphics
import Swifter

extension ElementController: Routeable {
    
    var name: String { return "element" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let bodyString = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        var bodyParameters: [String] = bodyString.components(separatedBy: "\n")
        bodyParameters.removeFirst()
        let actionValue = bodyParameters.removeFirst()
        
        guard let action = ElementAction(rawValue: actionValue) else {
            return .internalServerError
        }
        
        switch action {
        case .tap:      return tapHandler(bodyParameters)
        case .press:    return .accepted
        case .input:    return inputHandler(bodyParameters)
        case .swipe:    return swipeHandler(bodyParameters)
        case .scripting:return .accepted
        }
    }
}

final class ElementController {
    
    enum ElementAction: String {
        case tap
        case swipe
        case scripting
        case input
        case press
    }
    
    struct ScriptingOutput: Encodable {
        let status: String
        let message: String?
        let error: String?
    }
    
    struct ScriptingInput: Encodable {
        let script: String
        let frame: CGRect
    }
    
    private func scripting(_ parameters: [String]) -> HttpResponse {
        // let coordinate: XCUICoordinate
        // let script: String
        
        /* let executor = ScriptingExecutor(script);
         
         do {
         if let message = try executor.execute(coordinate: coordinate) {
         return Output(status: "0", message: message, error: nil)
         } else {
         return Output(status: "0", message: "", error: nil)
         }
         } catch {
         return Output(status: "", message: nil, error: error.localizedDescription)
         }
         
         let executor = ScriptingExecutor(script)
         
         let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
         let coordinate = normalized.withOffset(CGVector(dx: calculateX, dy: calculateY))
         
         do {
         try _ = executor.execute(coordinate: coordinate)
         self.resultElement["status"] = "0"
         self.resultElement["message"] = "script element"
         } catch {
         self.resultElement["status"] = "-11"
         self.resultElement["error"] = error.localizedDescription
         } */
        
        return Output(message: "scripting on element").toHttpResponse()
    }
    
    
    private func tapHandler(_ parameters: [String]) -> HttpResponse {
        guard application.state == .runningForeground else {
            return Output(message: "tap on element").toHttpResponse()
        }
        
        let vector = ElementController.getVector(parameters)
        application.coordinate(withNormalizedOffset: CGVector.zero).withOffset(vector).tap()
        
        return Output(message: "tap on element").toHttpResponse()
    }
    
    private func swipeHandler(_ parameters: [String]) -> HttpResponse {
        guard application.state == .runningForeground else {
            return Output(message: "tap on element").toHttpResponse()
        }
        
        let directionX = Double(parameters[2])!
        let directionY = Double(parameters[3])!
        
        let pressVector = ElementController.getVector(parameters)
        let dragToVector = CGVector(dx: pressVector.dx + CGFloat(directionX), dy: pressVector.dy + CGFloat(directionY))
        
        let appCoordinate = application.coordinate(withNormalizedOffset: .zero)
        let pressCoordinate = appCoordinate.withOffset(pressVector)
        let dragToCoordinate = appCoordinate.withOffset(dragToVector)
        
        pressCoordinate.press(forDuration: 0.1, thenDragTo: dragToCoordinate)
        
        return Output(message: "swipe element").toHttpResponse()
    }
    
    private func inputHandler(_ parameters: [String]) -> HttpResponse {
        guard application.state == .runningForeground else {
            return Output(message: "tap on element").toHttpResponse()
        }
        
        guard parameters.count > 0 else {
            return Output(message: "missing parameters").toHttpResponse()
        }
        
        let text = parameters[0]
        if text == "&empty;" {
            return Output(message: "no keyboard on screen for tap text").toHttpResponse()
        } else {
            if (application.keyboards.count > 0) {
                application.typeText(text)
                //sendLogs(type: logType.INFO, message: "Type text: \(text)")
                return Output(message: "element send keys : \(text)").toHttpResponse()
            } else {
                return Output(message: "no keyboard on screen for tap text").toHttpResponse()
            }
        }
    }
    
    private func press(duration: TimeInterval, paths: [String]) -> HttpResponse {
        // let app = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        // app.activate()
        
        // for path in paths {
        // let startCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        // let endCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // let othercoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7))
        
        // let second = Timer.scheduledTimer(timeInterval: 0, target: nil, selector: #selector(test1), userInfo: nil, repeats: false)
        // let first = Timer.scheduledTimer(timeInterval: 0, target: nil, selector: #selector(test2), userInfo: nil, repeats: false)
        
        // endCoordinate.press(forDuration: 0, thenDragTo: startCoordinate)
        // endCoordinate.press(forDuration: 0, thenDragTo: othercoordinate)
        
        // test1()
        // test2()
        
        // }
        
        // startCoordinate.doubleTap()
        
        return Output(message: "ok").toHttpResponse()
    }
    
    private static func getVector(_ parameters: [String]) -> CGVector {
        let offsetX = Double(parameters[0])!
        let offsetY = Double(parameters[1])!
        
        let values = parameters.last!.split(separator: ";")
        let x = Double(values[0])!
        let y = Double(values[1])!
        
        let screenScale = Double(UIScreen.main.scale)
        let vectorX = (x + offsetX) / screenScale
        let vectorY = (y + offsetY) / screenScale
        
        return CGVector(dx: vectorX, dy: vectorY)
    }
}

