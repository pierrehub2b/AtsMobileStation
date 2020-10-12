//
//  CaptureController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import Swifter

extension CaptureController: Routeable {
    
    var name: String { return "capture" }
    
    func handleRoutes(_ request: HttpRequest) -> HttpResponse {
        let response = fetchCaptureInfo()
        print(response)
        return response
        // return fetchCaptureInfo()
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
