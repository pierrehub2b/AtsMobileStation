//
//  CaptureController.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation

extension CaptureController: Routeable {    
    var name: String {
        return "capture"
    }
    
    func handleParameters(_ parameters: [String], token: String?) throws -> Any {
        return try fetchCaptureInfo()
    }
}

final class CaptureController {
    
    enum CaptureError: Error {
        case noApp
    }
    
    private struct Output: Content {
        let status: String = "0"
        let message: String = "root_description"
        let deviceWidth: Double
        let deviceHeight: Double
        let root: String
    }
    
    private func fetchCaptureInfo() throws -> Output {
        guard let app = app else { throw CaptureError.noApp }

        if asChanged {
            appDomDesc = app.debugDescription
            asChanged = false
        }
        
        let root = appDomDesc
        return Output(deviceWidth: channelWidth, deviceHeight: channelHeight, root: root)
    }
}
