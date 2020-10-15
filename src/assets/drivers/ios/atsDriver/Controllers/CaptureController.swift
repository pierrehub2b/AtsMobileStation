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
import Swifter

extension CaptureController: Routeable {
    
    var name: String { return "capture" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        return fetchCaptureInfo()
    }
}

final class CaptureController {
    
    private struct CaptureOutput: Encodable {
        let status = "0"
        let message = "root_description"
        let deviceWidth = Device.current.channelWidth
        let deviceHeight = Device.current.channelHeight
        let root: String
    }
        
    private func fetchCaptureInfo() -> HttpResponse {        
        guard let application = application else {
            return Output(message: "no app has been launched", status: "-99").toHttpResponse()
        }

        return CaptureOutput(root: application.debugDescription).toHttpResponse()
    }
}
