//
//  ElementController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import XCTest
import CoreGraphics

extension ElementController: Routeable {
    var name: String {
        return "element"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        guard parameters.count > 1 else {
            throw Router.RouterError.missingParameters
        }
        
        let actionParameter = parameters[1]
        guard let action = ElementAction(rawValue: actionParameter) else {
            throw Router.RouterError.missingParameters
        }
        
        switch action {
        case .tap:
            let coordinate = try fetchCoordinates(parameters)
            return tap(coordinate)
        case .swipe:
            let from = try fetchCoordinates(parameters)
            
            guard parameters.count > 5 else { throw Router.RouterError.missingParameters }
            
            let directionX = Double(parameters[4]) ?? 0.0
            let directionY = Double(parameters[5]) ?? 0.0
            
            return swipe(from, to: CGPoint(x: directionX, y: directionY))
        case .scripting:
            let coordinate = try fetchCoordinates(parameters)
            let script: String = ""
            return scripting(script, coordinate: coordinate)
        case .input:
            guard parameters.count > 2 else { throw Router.RouterError.missingParameters }
            let text = parameters[2]
            return input(text)
        }
    }
}

final class ElementController {
    
    enum ElementAction: String {
        case tap
        case swipe
        case scripting
        case input
    }
                
    private func scripting(_ script: String, coordinate: CGPoint) -> Content {
        /* let executor = ScriptingExecutor(script);
        
        do {
            if let message = try executor.execute(coordinate: coordinate) {
                return Router.Output(message: message)
            } else {
                return Router.Output(message: "scripting on element")
            }
        } catch {
            return Router.Output(message: error.localizedDescription, status: "-20")
        } */
        /*
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
        
        return Router.Output(message: "Scripting on element")
    }
    
    private func tap(_ coordinate: CGPoint) -> Content {
        let xCoordinate = Double(coordinate.x) * deviceWidth / channelWidth
        let yCoordinate = Double(coordinate.y) * deviceHeight / channelHeight
        
        if (app != nil) {
            let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let coordinate = normalized.withOffset(CGVector(dx: xCoordinate, dy: yCoordinate))
            coordinate.tap()
        } else {
            sendLogs(type: logType.ERROR, message: "App is null")
        }
        
        return Router.Output(message: "tap on element")
    }
    
    enum Direction {
        case horizontal
        case vertical
    }
    
    private func swipe(_ from: CGPoint, to: CGPoint) -> Content {
        if(app != nil) {
            var direction:Direction;
            var adjustment: CGFloat = 0
            if(to.x > 0) {
                direction = .horizontal
                adjustment = 1
            } else if(to.x < 0) {
                direction = .horizontal
                adjustment = -1
            } else if(to.y < 0) {
                direction = .vertical
                adjustment = -1
            } else {
                direction = .vertical
                adjustment = 1
            }
            
            let halfX : CGFloat = CGFloat(Double(from.x) / channelWidth)
            let halfY : CGFloat = CGFloat(Double(from.y) / channelHeight)
            let pressDuration : TimeInterval = 0.1
            
            let centre = app.coordinate(withNormalizedOffset: CGVector(dx: halfX, dy: halfY))
            let ySwipe = app.coordinate(withNormalizedOffset: CGVector(dx: halfX, dy: halfY + adjustment))
            let xSwipe = app.coordinate(withNormalizedOffset: CGVector(dx: halfX + adjustment, dy: halfY))
            
            switch direction {
            case .vertical:
                centre.press(forDuration: pressDuration, thenDragTo: ySwipe)
                break
            case .horizontal:
                centre.press(forDuration: pressDuration, thenDragTo: xSwipe)
                break
            }
        } else {
            sendLogs(type: logType.ERROR, message: "App is null")
        }
                
        // forceCapture = true

        return Router.Output(message: "swipe element")
    }
    
    private func input(_ text: String) -> Content {
        if text == "&empty;" {
            return Router.Output(message: "no keyboard on screen for tap text")
        } else {
            if(app.keyboards.count > 0) {
                app.typeText(text)
                //sendLogs(type: logType.INFO, message: "Type text: \(text)")
                return Router.Output(message: "element send keys : \(text)")
            } else {
                return Router.Output(message: "no keyboard on screen for tap text")
            }
        }
    }
    
    private func fetchCoordinates(_ parameters: [String]) throws -> CGPoint {
        let coordinates = parameters.last!.split(separator: ";")

        guard parameters.count == 5 else {
            throw Router.RouterError.missingParameters
        }
        
        guard let x = Double(coordinates[0]),
            let y = Double(coordinates[1]),
            let width = Double(coordinates[2]),
            let height = Double(coordinates[3]) else {
            throw Router.RouterError.missingParameters
        }
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
           
        let elementX = Double(rect.origin.x)
        let elementY = Double(rect.origin.y)
        let elementHeight = Double(rect.height)
        
        var offSetX = 0.0
        var offSetY = 0.0
        
        let offsetYShift = 33.0
        
        if (parameters.count > 3) {
            offSetX = Double(parameters[2])!
            offSetY = Double(parameters[3])! + offsetYShift
            if (offSetY > elementHeight) {
                offSetY = Double(parameters[3])!
            }
        }
                
        let calculateX = elementX + offSetX
        let calculateY = elementY + offSetY
        
        return CGPoint(x: calculateX, y: calculateY)
    }
}
