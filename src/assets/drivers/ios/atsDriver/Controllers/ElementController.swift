//
//  ElementController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

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
    
    struct Output: Content {
        let status: String
        let message: String?
        let error: String?
    }
    
    struct ScriptingInput: Content {
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
        
        return try! Router.Output(message: "scripting on element").toHttpResponse()
    }
    
    private func tapHandler(_ parameters: [String]) -> HttpResponse {
        let device = Device.current
        
        do {
            let coordinate = try fetchCoordinates(parameters)
            let xCoordinate = Double(coordinate.x) * device.deviceWidth / device.channelWidth
            let yCoordinate = Double(coordinate.y) * device.deviceHeight / device.channelHeight
            
            let normalized = application.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let uiCoordinate = normalized.withOffset(CGVector(dx: xCoordinate, dy: yCoordinate))
            uiCoordinate.tap()
            
            return try! Router.Output(message: "tap on element").toHttpResponse()
        } catch {
            return .internalServerError
        }
    }
    
    enum Direction {
        case horizontal
        case vertical
    }
    
    private func swipeHandler(_ parameters: [String]) -> HttpResponse {
        guard parameters.count > 5 else {
            return try! Router.Output(message: "missing parameters").toHttpResponse()
        }
        
        let directionX = Double(parameters[3]) ?? 0.0
        let directionY = Double(parameters[4]) ?? 0.0
        let to = CGPoint(x: directionX, y: directionY)
        
        var direction:Direction
        var adjustment: CGFloat = 0
        if to.x > 0 {
            direction = .horizontal
            adjustment = 1
        } else if to.x < 0 {
            direction = .horizontal
            adjustment = -1
        } else if to.y < 0 {
            direction = .vertical
            adjustment = -1
        } else {
            direction = .vertical
            adjustment = 1
        }
        
        do {
            let from = try fetchCoordinates(parameters)
            
            let device = Device.current
            let halfX: CGFloat = CGFloat(Double(from.x) / device.channelWidth)
            let halfY: CGFloat = CGFloat(Double(from.y) / device.channelHeight)
            let pressDuration : TimeInterval = 0.1
            
            let center = application.coordinate(withNormalizedOffset: CGVector(dx: halfX, dy: halfY))
            let ySwipe = application.coordinate(withNormalizedOffset: CGVector(dx: halfX, dy: halfY + adjustment))
            let xSwipe = application.coordinate(withNormalizedOffset: CGVector(dx: halfX + adjustment, dy: halfY))
            
            center.press(forDuration: pressDuration, thenDragTo: direction == .vertical ? ySwipe : xSwipe)
            
            return try! Router.Output(message: "swipe element").toHttpResponse()
        } catch {
            return try! Router.Output(message: "problem").toHttpResponse()
        }
    }
    
    private func inputHandler(_ parameters: [String]) -> HttpResponse {
        guard parameters.count > 2 else {
            return try! Router.Output(message: "missing parameters").toHttpResponse()
        }
        
        let text = parameters[2]
        if text == "&empty;" {
            return try! Router.Output(message: "no keyboard on screen for tap text").toHttpResponse()
        } else {
            if(application.keyboards.count > 0) {
                application.typeText(text)
                //sendLogs(type: logType.INFO, message: "Type text: \(text)")
                return try! Router.Output(message: "element send keys : \(text)").toHttpResponse()
            } else {
                return try! Router.Output(message: "no keyboard on screen for tap text").toHttpResponse()
            }
        }
    }
    
    private func press(duration: TimeInterval, paths: [String]) -> Content {
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
        
        return Router.Output(message: "ok")
    }
    
    private func fetchCoordinates(_ parameters: [String]) throws -> CGPoint {
        let coordinates = parameters.last!.split(separator: ";")
                
        let xCoordinates = Double(coordinates[0])!
        let yCoordinates = Double(coordinates[1])!
        let widthCoordinates = Double(coordinates[2])!
        let heightCoordinates = Double(coordinates[3])!
        
        let rect = CGRect(x: xCoordinates, y: yCoordinates, width: widthCoordinates, height: heightCoordinates)
        
        let elementX = Double(rect.origin.x)
        let elementY = Double(rect.origin.y)
        let elementHeight = Double(rect.height)
        
        var offSetX = 0.0
        var offSetY = 0.0
        
        let offsetYShift = 33.0
        
        if (parameters.count == 3) {
            offSetX = Double(parameters[0])!
            offSetY = Double(parameters[1])! + offsetYShift
            if (offSetY > elementHeight) {
                offSetY = Double(parameters[1])!
            }
        }
        
        let calculateX = elementX + offSetX
        let calculateY = elementY + offSetY
        
        return CGPoint(x: calculateX, y: calculateY)
    }
}

