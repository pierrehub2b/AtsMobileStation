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

extension ButtonController: Routeable {
    
    var name: String { return "sysbutton" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        guard let buttonName = String(bytes: request.body, encoding: .utf8) else {
            return .internalServerError
        }
        
        guard let action = Device.Button(rawValue: buttonName) else {
            return .internalServerError
        }
        
        switch action {
        case .lock:
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
            return Output(message: "press \(action.rawValue) button").toHttpResponse()
        default:
            return pressButton(action)
        }
    }
}

final class ButtonController {
    
    enum ButtonControllerError: Error {
        case unknowButton
    }
    
    private func pressButton(_ action:Device.Button) -> HttpResponse {
        if let deviceButton = transformAction(action) {
            XCUIDevice.shared.press(deviceButton)
            return Output(message: "press \(action.rawValue) button").toHttpResponse()
        } else {
            return Output(message: "press \(action.rawValue) button").toHttpResponse()
        }
    }
    
    private func transformAction(_ action:Device.Button) -> XCUIDevice.Button? {
        switch action {
        case .home:
            return XCUIDevice.Button.home
        default:
            return nil
        /* case .soundDown:
            #if TARGET_OS_SIMULATOR
            return nil
            #else
            return XCUIDevice.Button.soundDown
            #endif
        case .soundUp:
            #if TARGET_OS_SIMULATOR
            return nil
            #else
            return XCUIDevice.Button.soundUp
            #endif */
        }
    }
}
