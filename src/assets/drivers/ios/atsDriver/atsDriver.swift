//
//  AtsDriver2.swift
//  atsDriver
//
//  Created by Caipture on 07/10/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import XCTest
import Swifter
import Socket

enum ATSError: Error {
    case start
}

var application: XCUIApplication!

var continueExecution = true
var asChanged: Bool = true

class atsDriver: XCTestCase {

    private let httpServer = HTTPServerManager.current
    private let udpConnection = UDPConnect.current
    
    private var httpPort: in_port_t!
        
    override func setUpWithError() throws {
        guard let settingsFileURL = Bundle(for: atsDriver.self).url(forResource: "Settings", withExtension: "json") else {
            throw ATSError.start
        }
        
        let data = try Data(contentsOf: settingsFileURL)
        let settings = try JSONDecoder().decode(Settings.self, from: data)
            
        httpPort = settings.customPort
        let applications: [String]
        if Device.current.isSimulator {
            applications = try fetchSimulatorApps()
        } else {
            applications = settings.apps
        }
        
        guard applications.isEmpty == false else {
            throw ATSError.start
        }
        
        Device.current.setApplications(applications)
        
        application = XCUIApplication()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
           
        // Close if running
        httpServer.stopServer()
    }

    func testRunner() throws {
        udpConnection.start()
        httpServer.startServer(httpPort)        
    }
    
    func fetchSimulatorApps() throws -> [String] {
        guard let url = Bundle.main.url(forResource: "../../../../../Library/SpringBoard/IconState", withExtension: "plist"),
            let myDict = NSDictionary(contentsOf: url) as? [String:Any] else {
            throw ATSError.start
        }
        
        var appsInstalled = getAllAppIds(from: myDict)
        for itm in myDict {
            if(itm.key.contains("CFAppBundleID")) {
                appsInstalled.append(itm.value as! String)
            }
        }
        
        return appsInstalled
    }
    
    func getAllAppIds(from dic: [String: Any]) -> [String] {
        guard let iconLists = dic["iconLists"] as? [[Any]] else {
            return []
        }
        
        var icons: [String] = []
        for page in iconLists {
            for app in page {
                if let id = app as? String,
                    id.contains("com.") {
                    icons.append(id)
                }
                if let dic = app as? [String: Any] {
                    let iconsTemp = getAllAppIds(from: dic)
                    icons.append(contentsOf: iconsTemp)
                }
            }
        }
        
        guard let buttonBarList = dic["buttonBar"] as? [String] else {
            return icons
        }
        
        for app in buttonBarList {
            if app.contains("com.") {
                icons.append(app)
            }
        }
        
        return icons
    }
}
