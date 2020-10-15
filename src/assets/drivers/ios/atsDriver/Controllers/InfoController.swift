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
import UIKit
import Swifter

extension InfoController: Routeable {
    
    var name: String { return "info" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        return fetchInfo()
    }
}

final class InfoController {
    
    struct InfoOutput: Encodable {
        let message = "device capabilities"
        let status = "0"
        
        let brand = "Apple"

        let os: String
        let driverVersion: String
        let deviceWidth: CGFloat
        let deviceHeight: CGFloat
        let channelWidth: CGFloat
        let channelHeight: CGFloat
        let id: String
        let model: String
        let version: String
        let bluetoothName: String
        let systemName: String
        let simulator: Bool
        let applications: [Application]
    }
        
    func fetchInfo() -> HttpResponse {
        let device = Device.current
        return InfoOutput(
            os:             device.os,
            driverVersion:  device.driverVersion,
            deviceWidth:    device.deviceWidth,
            deviceHeight:   device.deviceHeight,
            channelWidth:   device.channelWidth,
            channelHeight:  device.channelHeight,
            id:             device.uuid,
            model:          device.modelName,
            version:        device.systemVersion,
            bluetoothName:  device.name,
            systemName:     device.description,
            simulator:      device.isSimulator,
            applications:   device.applications
        ).toHttpResponse()    
    }
}
