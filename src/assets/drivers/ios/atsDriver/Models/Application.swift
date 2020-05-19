//
//  Application.swift
//  atsDriver
//
//  Copyright © 2020 CAIPTURE. All rights reserved.
//


public struct Application: Codable {
    
    let label: String
    let packageName: String
    let version: String
    let icon: String
    
    static func setup() {
        applications = appsInstalled.map { Application(label: "CFBundleName", packageName: String($0), version: "", icon: DefaultAppIcon()) }
    }
}
