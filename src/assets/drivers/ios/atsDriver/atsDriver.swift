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
import UIKit
import XCTest
import Embassy
import Ambassador
import Socket

public var app: XCUIApplication!
public var appsInstalled: [String] = []
public var applications: [Application] = []
public var channelWidth = 1.0
public var channelHeight = 1.0
public var deviceWidth = 1.0
public var deviceHeight = 1.0
public var asChanged: Bool = true
public var appDomDesc: String = ""
public var continueExecution = true
public var udpPort: Int = 47633
public var osVersion = UIDevice.current.systemVersion
public var userAgent: String?
public var model = UIDevice.modelName.replacingOccurrences(of: "Simulator ", with: "")
// public var forceCapture = false

extension UIDevice {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

class atsDriver: XCTestCase {
    
    let driverVersion:String = "1.0.0"
    
    let udpThread = DispatchQueue(label: "udpQueue" + UUID().uuidString, qos: .userInitiated)
    var screenShotThread = DispatchQueue(label: "screenshotQueue" + UUID().uuidString, qos: .userInitiated)
    var port = 0
    // var currentAppIdentifier: String = ""
    var resultElement: [String: Any] = [:]
    // var flatStruct: [String: CGRect] = [:]
    var thread: Thread! = nil
    // var udpPort: Int = 47633
    // var continueRunningValue = true
    var connectedSockets = [Int32: Socket]()
    var imgView: Data? = nil
    // var leveledTableCount = 0
    var tcpSocket = socket(AF_INET, SOCK_STREAM, 0)
    // let osVersion = UIDevice.current.systemVersion
    // let model = UIDevice.modelName.replacingOccurrences(of: "Simulator ", with: "")
    // let simulator = UIDevice.modelName.range(of: "Simulator", options: .caseInsensitive) != nil
    // let uid = UIDevice.current.identifierForVendor!.uuidString
    let bluetoothName = UIDevice.current.name
    // var forceCapture = false;
    // var emptyImg:String = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="
    // var asChanged:Bool = true
    // var appDomDesc: String = ""
    // var continueExecution = true
    
    /* var applicationControls =
        [
            "any","other","application","group","window","sheet","drawer","alert","dialog","button","radioButton","radioGroup","checkbox","disclosureTriangle","popUpButton","comboBox","menuButton","toolbarButton","popOver",
            "keyboard","key","navigationBar","tabBar","tabGroup","toolBar","statusBar","table","tableRow","tableColumn","outline","outlineRow","browser","collectionView","slider","pageIndicator","progressIndicator",
            "activityIndicator","segmentedControl","picker","pickerWheel","switch","toogle","link","image","icon","searchField","scrollView","scrollBar","staticText","textField","secureTextField","datePicker","textView",
            "menu","menuItem","menuBar","menuBarItem","map","webView","incrementArrow","decrementArrow","timeline","ratingIndicator","valueIndicator","splitGroup","splitter","relevanceIndicator","colorWell","helpTag","matte",
            "dockItem","ruler","rulerMarker","grid","levelIndicator","cell","layoutArea","layoutItem","handle","stepper","tab","touchBar","statusItem"
    ] */
    
    override func setUp() {
                
        super.setUp()
        continueAfterFailure = true
        
        udpPort = Int.random(in: 32000..<64000)
        sendLogs(type: logType.STATUS, message: "UDP PORT for " + self.bluetoothName + " = " + String(udpPort))
        
        udpThread.async {
            //sendLogs(type: logType.INFO, message: "Starting UDP server on port: \(self.udpPort)")
            self.udpStart()
        }
        
        var customPort = "";
        
        let testBundle = Bundle(for: atsDriver.self)
        if let url = testBundle.url(forResource: "Settings", withExtension: "plist"),
            let myDict = NSDictionary(contentsOf: url) as? [String:Any] {
            customPort = myDict["CFCustomPort"].unsafelyUnwrapped as! String;
            //sendLogs(type: logType.INFO, message: "Fixed port defined: \(customPort)")
            for itm in myDict {
                if(itm.key.contains("CFAppBundleID")) {
                    appsInstalled.append(itm.value as! String)
                }
            }
        }
        
        if(UIDevice.isSimulator && appsInstalled.count == 0) {
            let bundleMain = Bundle.main
            if let url = bundleMain.url(forResource: "../../../../../Library/SpringBoard/IconState", withExtension: "plist"),
                let myDict = NSDictionary(contentsOf: url) as? [String:Any] {
                appsInstalled = getAllAppIds(from: myDict)
                for itm in myDict {
                    if(itm.key.contains("CFAppBundleID")) {
                        appsInstalled.append(itm.value as! String)
                    }
                }
            }
        }
        
        
        if !UIDevice.isSimulator {
            // XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        }
        
        if(customPort != "") {
            let (isFree, _) = checkTcpPortForListen(port: UInt16(customPort)!)
            if(isFree == true) {
                self.port = Int(customPort)!
            } else {
                sendLogs(type: logType.STATUS, message: "** Port unavailable **")
                return;
            }
        } else {
            for i in 8080..<65000 {
                let (isFree, _) = checkTcpPortForListen(port: UInt16(i))
                if (isFree == true && i != udpPort) {
                    self.port = i
                    break
                }
            }
        }
        //sendLogs(type: logType.INFO, message: "Start HTTP server : \(customPort)")
        Application.setup()
        self.setupApp()
        self.setupWebApp()
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
        
    func udpStart(){
        do {
            var data = Data()
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            
            repeat {
                let currentConnection = try socket.listen(forMessage: &data, on: udpPort)
                self.addNewConnection(socket: socket, currentConnection: currentConnection)
            } while true
        } catch let error {
            guard let socketError = error as? Socket.Error else {
                sendLogs(type: logType.ERROR, message: "Unexpected error...")
                return
            }
            sendLogs(type: logType.ERROR, message: "Error on socket instance creation: \(socketError.description)")
        }
    }
    
    func addNewConnection(socket: Socket, currentConnection: (bytesRead: Int, address: Socket.Address?)) {
        let bufferSize = 2000
        var offset = 0
        
        do {
            let workItem = DispatchWorkItem {
                self.refreshView()
            }
            
            DispatchQueue.init(label: "getImg").async(execute: workItem)
            workItem.wait()
            
            let img = self.imgView
            if(img != nil) {
                repeat {
                    let thisChunkSize = ((img!.count - offset) > bufferSize) ? bufferSize : (img!.count - offset);
                    var chunk = img!.subdata(in: offset..<offset + thisChunkSize)
                    offset += thisChunkSize
                    let uint32Offset = UInt32(offset - thisChunkSize)
                    let uint32RemainingData = UInt32(img!.count - offset)
                    
                    let offSetTable = self.toByteArrary(value: uint32Offset)
                    let remainingDataTable = self.toByteArrary(value: uint32RemainingData)
                    
                    chunk.insert(contentsOf: offSetTable + remainingDataTable, at: 0)
                    
                    try socket.write(from: chunk, to: currentConnection.address!)
                    
                } while (offset < img!.count);
            }
        }
        catch let error {
            guard let socketError = error as? Socket.Error else {
                sendLogs(type: logType.ERROR, message: "Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                return
            }
            if continueExecution {
                sendLogs(type: logType.ERROR, message: "Error reported by connection at \(socket.remoteHostname):\(socket.remotePort):\n \(socketError.description)")
            }
        }
        
    }
    
    func refreshView() {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: channelWidth, height: channelHeight), true, 0.60)
        XCUIScreen.main.screenshot().image.draw(in: CGRect(x: 0, y: 0, width: channelWidth, height: channelHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.imgView = (newImage ?? UIImage()).jpegData(compressionQuality: 0.2)
    }
    
    func toByteArrary<T>(value: T)  -> [UInt8] where T: UnsignedInteger, T: FixedWidthInteger{
        var bigEndian = value.bigEndian
        let count = MemoryLayout<T>.size
        let bytePtr = withUnsafePointer(to: &bigEndian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return Array(bytePtr)
    }
    
    // setup the Embassy web server for testing
    private func setupWebApp() {
        
        let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
        let server = DefaultHTTPServer(eventLoop: loop, interface: "0.0.0.0", port: self.port) { environ, startResponse, sendBody in
            
            let queryString = environ["PATH_INFO"]! as! String
            let token = (environ["HTTP_TOKEN"] as? String)// .replacingOccurrences(of:"\"", with: "")
            userAgent = (environ["HTTP_USER_AGENT"] as? String ?? "") + " " + (environ["HTTP_HOST"] as? String ?? "")
            let action = queryString.replacingOccurrences(of: "/", with: "")
            var parameters: [String] = []
            
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                guard let textData = String(bytes: data, encoding: .utf8) else { return }
                
                let tableData = textData.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n")
                tableData.forEach { parameters.append(String($0)) }
            }
            
            do {
                let result = try Router.main.route(action, parameters: parameters, token: token)
                if let resultElement = result as? [String: Any] {
                    self.resultElement = resultElement
                    startResponse("200 OK", [("Content-Type", "application/json")])
                    if let theJSONData = try?  JSONSerialization.data(withJSONObject: self.resultElement),
                        let theJSONText = String(data: theJSONData, encoding: String.Encoding.utf8) {
                        sendBody(Data(theJSONText.utf8))
                    }
                    sendBody(Data())
                } else if let screenshot = result as? Data {
                    startResponse("200 OK", [("Content-Type", "application/octet-stream"),("Content-length", screenshot.count.description)])
                    //sendLogs(type: logType.INFO, message: "Get screenshot informations")
                    self.screenShotThread.sync {
                        sendBody(screenshot)
                        //sendLogs(type: logType.INFO, message: "Screenshot sended with \(bytes.count) bytes")
                        usleep(1000000)
                    }
                    self.screenShotThread.sync {
                        sendBody(Data())
                        //sendLogs(type: logType.INFO, message: "Flush screenshot thread")
                    }
                } else {
                    
                }
                
                // self.resultElement = try Router.main.route(action, parameters: parameters)
            } catch Router.RouterError.badRoute {
                self.resultElement["status"] = "-11"
                self.resultElement["message"] = "unknow command"
                startResponse("200 OK", [("Content-Type", "application/json")])
                if let theJSONData = try?  JSONSerialization.data(withJSONObject: self.resultElement),
                    let theJSONText = String(data: theJSONData, encoding: String.Encoding.utf8) {
                    sendBody(Data(theJSONText.utf8))
                }
                sendBody(Data())
            } catch CaptureController.CaptureError.noApp {
                self.resultElement["message"] = "no app has been launched"
                self.resultElement["status"] = "-99"
                startResponse("200 OK", [("Content-Type", "application/json")])
                if let theJSONData = try?  JSONSerialization.data(withJSONObject: self.resultElement),
                    let theJSONText = String(data: theJSONData, encoding: String.Encoding.utf8) {
                    sendBody(Data(theJSONText.utf8))
                }
                sendBody(Data())
            } catch Router.RouterError.missingParameters {
                self.resultElement["message"] = "missing parameter"
                self.resultElement["status"] = "-99"
                startResponse("200 OK", [("Content-Type", "application/json")])
                if let theJSONData = try?  JSONSerialization.data(withJSONObject: self.resultElement),
                    let theJSONText = String(data: theJSONData, encoding: String.Encoding.utf8) {
                    sendBody(Data(theJSONText.utf8))
                }
                sendBody(Data())
            } catch {
                self.resultElement["status"] = "-11"
                self.resultElement["message"] = "unknow error"
                startResponse("200 OK", [("Content-Type", "application/json")])
                if let theJSONData = try?  JSONSerialization.data(withJSONObject: self.resultElement),
                    let theJSONText = String(data: theJSONData, encoding: String.Encoding.utf8) {
                    sendBody(Data(theJSONText.utf8))
                }
                sendBody(Data())
            }
            
            /* if(action == "") {
                
            } */
            
            /* else if(action == ActionsEnum.CAPTURE.rawValue){
                if(app == nil) {
                    self.resultElement["message"] = "no app has been launched"
                    self.resultElement["status"] = "-99"
                } else {
                    self.resultElement["message"] = "root_description"
                    self.resultElement["status"] = "0"
                    self.resultElement["deviceHeight"] = self.channelHeight
                    self.resultElement["deviceWidth"] = self.channelWidth
                    if(self.asChanged) {
                        self.appDomDesc = app.debugDescription
                        self.asChanged = false
                    }
                    self.resultElement["root"] = self.appDomDesc
                }
            } */
            
            /* else if(action == ActionsEnum.SCREENSHOT.rawValue){
                let screenshot = XCUIScreen.main.screenshot()
                screenshot.image.pngData()!.co
                let bytes = self.getArrayOfBytesFromImage(imageData: screenshot.image.pngData()!)
                
                startResponse("200 OK", [("Content-Type", "application/octet-stream"),("Content-length", bytes.count.description)])
                //sendLogs(type: logType.INFO, message: "Get screenshot informations")
                self.screenShotThread.sync {
                    sendBody(Data(bytes: bytes))
                    //sendLogs(type: logType.INFO, message: "Screenshot sended with \(bytes.count) bytes")
                    usleep(1000000)
                }
                self.screenShotThread.sync {
                    sendBody(Data())
                    //sendLogs(type: logType.INFO, message: "Flush screenshot thread")
                }
            } */
            
            /* else if(action == ActionsEnum.INFO.rawValue){
                let testBundle = Bundle(for: atsDriver.self)
                if(!UIDevice.isSimulator) {
                    self.appsInstalled = []
                    if let url = testBundle.url(forResource: "Settings", withExtension: "plist"),
                        let myDict = NSDictionary(contentsOf: url) as? [String:Any] {
                        for itm in myDict {
                            if(itm.key.contains("CFAppBundleID")) {
                                self.appsInstalled.append(itm.value as! String)
                            }
                        }
                    }
                    self.setupInstalledApp();
                }
                
                self.driverInfoBase()
                self.resultElement["message"] = "device capabilities"
                self.resultElement["status"] = "0"
                self.resultElement["id"] = self.uid
                self.resultElement["model"] = self.model
                self.resultElement["manufacturer"] = "Apple"
                self.resultElement["brand"] = "Apple"
                self.resultElement["version"] = self.osVersion
                self.resultElement["bluetoothName"] = self.bluetoothName
                self.resultElement["simulator"] = self.simulator
                self.resultElement["applications"] = self.applications
            } */
            
            /* else {
                if(parameters.count > 0) {
                    let firstParam = parameters.first! */
                    
                    /* if(action == ActionsEnum.DRIVER.rawValue){
                        if (ActionsEnum.START.rawValue == firstParam) {
                            self.continueExecution = true
                            self.driverInfoBase()
                            self.resultElement["status"] = "0"
                            self.resultElement["screenCapturePort"] = self.udpPort
                        } else {
                            if(ActionsEnum.STOP.rawValue == firstParam) {
                                if(app != nil){
                                    app.terminate()
                                }
                                //sendLogs(type: logType.INFO, message: "Terminate app")
                                if !UIDevice.isSimulator {
                                    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
                                }
                                self.resultElement["status"] = "0"
                                self.resultElement["message"] = "stop ats driver"
                            } else {
                                if(ActionsEnum.QUIT.rawValue == firstParam) {
                                    if(app != nil){
                                        app.terminate()
                                    }
                                    //sendLogs(type: logType.INFO, message: "Terminate app")
                                    if !UIDevice.isSimulator {
                                        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
                                    }
                                    self.continueExecution = false
                                    self.resultElement["status"] = "0"
                                    self.resultElement["message"] = "close ats driver"
                                } else if(ActionsEnum.INFO.rawValue == firstParam) {
                                    self.resultElement["status"] = "0"
                                    self.resultElement["info"] = self.getAppInfo()
                                } else {
                                    self.resultElement["message"] = "missiing driver action type " + firstParam
                                    self.resultElement["status"] = "-42"
                                }
                            }
                        }
                    } */
                    
                    /* else if(action == ActionsEnum.BUTTON.rawValue){
                        if(DeviceButtons.HOME.rawValue == firstParam) {
                            XCUIDevice.shared.press(.home)
                            self.resultElement["status"] = "0"
                            self.resultElement["message"] = "press home button"
                        } else {
                            if(DeviceButtons.ORIENTATION.rawValue == firstParam) {
                                if(XCUIDevice.shared.orientation == .landscapeLeft) {
                                    XCUIDevice.shared.orientation = .portrait
                                    self.resultElement["status"] = "0"
                                    self.resultElement["message"] = "orientation to portrait mode"
                                } else {
                                    XCUIDevice.shared.orientation = .landscapeLeft
                                    self.resultElement["status"] = "0"
                                    self.resultElement["message"] = "orientation to landscape mode"
                                }
                            } else {
                                self.resultElement["message"] = "unknow button " + firstParam
                                self.resultElement["status"] = "-42"
                            }
                        }
                    } */
                    
                    /* else if(action == ActionsEnum.ELEMENT.rawValue){
                        if(parameters.count > 1){
                            if(ActionsEnum.INPUT.rawValue == parameters[1]) {
                                let text = parameters[2]
                                if(text == ActionsEnum.EMPTY.rawValue) {
                                    //app.typeText(XCUIKeyboardKey.clear.rawValue)
                                } else {
                                    self.resultElement["status"] = "0"
                                    if(app.keyboards.count > 0) {
                                        app.typeText(text)
                                        //sendLogs(type: logType.INFO, message: "Type text: \(text)")
                                        self.resultElement["message"] = "element send keys : " + text
                                    } else {
                                        self.resultElement["message"] = "no keyboard on screen for tap text"
                                    }
                                }
                            } else {
                                
                                let coordinates = parameters.last!.split(separator: ";")
                                let frame:CGRect = CGRect(
                                    x: Double(coordinates[0])!,
                                    y: Double(coordinates[1])!,
                                    width: Double(coordinates[2])!,
                                    height: Double(coordinates[3])!
                                )
                                
                                let elementX = frame.x
                                let elementY = frame.y
                                let elementHeight = frame.height
                                
                                var offSetX = 0.0
                                var offSetY = 0.0
                                if (parameters.count > 3) {
                                    offSetX = Double(parameters[2])!
                                    offSetY = Double(parameters[3])! + self.offsetYShift
                                    if (offSetY > elementHeight) {
                                        offSetY = Double(parameters[3])!
                                    }
                                }
                                
                                let calculateX = elementX + offSetX
                                let calculateY = elementY + offSetY
                                
                                if (ActionsEnum.TAP.rawValue == parameters[1]) {
                                    self.tapCoordinate(at: (calculateX * self.deviceWidth / self.channelWidth), and: (calculateY * self.deviceHeight / self.channelHeight))
                                    self.resultElement["status"] = "0"
                                    self.resultElement["message"] = "tap on element"
                                } else if (ActionsEnum.SWIPE.rawValue == parameters[1]) {
                                    let directionX = (Double(parameters[4]) ?? 0.0)
                                    let directionY = (Double(parameters[5]) ?? 0.0)
                                    self.swipeCoordinate(x: calculateX, y: calculateY, swipeX: directionX, swipeY: directionY)
                                    self.forceCapture = true;
                                    self.resultElement["status"] = "0"
                                    self.resultElement["message"] = "swipe element"
                                } else if (ActionsEnum.scripting.rawValue == parameters[1]) {
                                    let script = parameters.last!
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
                                    }
                                }
                                
                            }
                        }
                    } */
                    
                    /*else if(action == ActionsEnum.APP.rawValue){
                        if(ActionsEnum.START.rawValue == firstParam) {
                            app = XCUIApplication.init(bundleIdentifier: parameters[1])
                            if(self.appsInstalled.contains(parameters[1]) || (self.appsInstalled.count == 0 && self.applications.count == 0)) {
                                app.launch()
                                //sendLogs(type: logType.INFO, message: "Launching app \(parameters[1])")
                                self.resultElement["status"] = "0"
                                self.resultElement["label"] = app.label
                                self.resultElement["icon"] = self.emptyImg
                                self.resultElement["version"] = "0.0.0"
                            } else {
                                sendLogs(type: logType.ERROR, message: "Error on app launching: \(parameters[1])")
                                self.resultElement["message"] = "app package not found : " + parameters[1]
                                self.resultElement["status"] = "-51"
                                app = nil
                            }
                        } else if(ActionsEnum.SWITCH.rawValue == firstParam) {
                            app = XCUIApplication(bundleIdentifier: parameters[1])
                            //sendLogs(type: logType.INFO, message: "Switch app \(parameters[1])")
                            app.activate()
                            self.resultElement["message"] = "switch app " + parameters[1]
                            self.resultElement["status"] = "0"
                        } else if(ActionsEnum.STOP.rawValue == firstParam) {
                            app = XCUIApplication(bundleIdentifier: parameters[1])
                            app.terminate()
                            app = nil;
                            //sendLogs(type: logType.INFO, message: "Stop app \(parameters[1])")
                            self.resultElement["message"] = "stop app " + parameters[1]
                            self.resultElement["status"] = "0"
                        } else if(ActionsEnum.INFO.rawValue == firstParam) {
                            var info: [String:String] = [:]
                            info["os"] = "ios"
                            info["icon"] = ""
                            info["label"] = ""
                            self.resultElement["status"] = "0"
                            self.resultElement["info"] = info
                        } else {
                            self.resultElement["message"] = "missing app action type " + firstParam
                            self.resultElement["status"] = "-42"
                        }
                    } */
                /* } else {
                    self.resultElement["message"] = "missing driver action"
                    self.resultElement["status"] = "-41"
                } */
            /* }
            if(action != ActionsEnum.CAPTURE.rawValue){
                asChanged = true
            } */
            /* startResponse("200 OK", [("Content-Type", "application/json")])
            if let theJSONData = try?  JSONSerialization.data(withJSONObject: self.resultElement),
                let theJSONText = String(data: theJSONData, encoding: String.Encoding.utf8) {
                sendBody(Data(theJSONText.utf8))
            }
            sendBody(Data()) */
        }
        
        let wifiAdress = getWiFiAddress()
        
    // Start HTTP server to listen on the port
        try! server.start()
        if(wifiAdress != nil) {
            let endPoint = wifiAdress! + ":" + String(self.port)
            sendLogs(type: logType.STATUS, message: "ATSDRIVER_DRIVER_HOST=" + endPoint)
            loop.runForever()
        } else {
            sendLogs(type: logType.STATUS, message: "** WIFI NOT CONNECTED **")
        }
    }
        
    /* func getArrayOfBytesFromImage(imageData:Data) ->[UInt8]{
        return imageData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: imageData.count))
        }
    } */
    
    /* func matchingStrings(input: String, regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = input as NSString
        let results  = regex.matches(in: input, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    } */
    
    /* func split(input: String, regex: String) -> [String] {
        
        guard let re = try? NSRegularExpression(pattern: regex, options: [])
            else { return [] }
        
        let nsString = input as NSString // needed for range compatibility
        let stop = "<SomeStringThatYouDoNotExpectToOccurInSelf>"
        let modifiedString = re.stringByReplacingMatches(
            in: input,
            options: [],
            range: NSRange(location: 0, length: nsString.length),
            withTemplate: "")
        return modifiedString.components(separatedBy: stop)
    } */
    
    /* func getAppInfo() -> String {
        if(app != nil) {
            let pattern = "'(.*?)'"
            let packageName = self.matchingStrings(input: String(app.description), regex: pattern).first?[1]
            var informations: [String:String] = [:]
            informations["packageName"] = packageName
            informations["activity"] = getStateStringValue(rawValue: app.state.rawValue)
            informations["system"] = model + " " + osVersion
            informations["label"] = app.label
            informations["icon"] = ""
            informations["version"] = ""
            informations["os"] = "ios"
            return self.convertIntoJSONString(arrayObject: informations)
        } else {
            return ""
        }
    } */
    
    /* func cleanString(input: String) -> String {
        var output = input.replacingOccurrences(of: "{", with: "")
        output = output.replacingOccurrences(of: "}", with: "")
        return output.replacingOccurrences(of: " ", with: "")
    } */
    
    /* func tapCoordinate(at xCoordinate: Double, and yCoordinate: Double) {
        if(app != nil) {
            let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let coordinate = normalized.withOffset(CGVector(dx: xCoordinate, dy: yCoordinate))
            coordinate.tap()
        } else {
            sendLogs(type: logType.ERROR, message: "App is null")
        }
        
    } */
    
    /* enum direction : Int {
        case horizontal, vertical
    } */
        
    /* func retrieveElement(parameter: String, field: String) -> XCUIElement? {
        var fieldValue = field.replacingOccurrences(of: "%27", with: "'")
        fieldValue = fieldValue.replacingOccurrences(of: "%22", with: "'")
        fieldValue = fieldValue.replacingOccurrences(of: "%20", with: " ")
        let predicate = NSPredicate(format: "\(parameter) == '\(fieldValue)'")
        if(app == nil) {
            return nil
        }
        let elem = app.descendants(matching: .any).element(matching: predicate)
        if(elem.exists) {
            return elem.firstMatch
        } else {
            return nil
        }
    } */
        
    /* func convertIntoJSONString(arrayObject: [String:String]) -> String {
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(arrayObject)
            let json = String(data: jsonData, encoding: String.Encoding.utf8) ?? "no values"
            return json
        } catch let error as NSError {
            sendLogs(type: logType.ERROR, message: "Array convertIntoJSON - \(error.description)")
        }
        return ""
    } */
    
    /* func stringify(json: Any, prettyPrinted: Bool = false) -> String {
        var options: JSONSerialization.WritingOptions = []
        if prettyPrinted {
            options = JSONSerialization.WritingOptions.prettyPrinted
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: options)
            if let string = String(data: data, encoding: String.Encoding.utf8) {
                return string
            }
        } catch {
            sendLogs(type: logType.ERROR, message: "Cannot Stringify JSON")
        }
        
        return ""
    } */
    
    func getQueryStringParameter(query_string: String, param: String) -> String {
        let params = query_string.components(separatedBy: "&")
        for item in params {
            let currentParam = item.components(separatedBy: "=")
            if(currentParam.count != 2) { return "" }
            if(currentParam[0] == param) {
                return currentParam[1]
            }
        }
        return ""
    }
    
    // set up XCUIApplication
    private func setupApp() {
        app = XCUIApplication()
        app!.launchEnvironment["RESET_LOGIN"] = "1"
        app!.launchEnvironment["ENVOY_BASEURL"] = "http://localhost:\(self.port)"
    }
    
    /* func driverInfoBase() {
        
        // Application size
        let screenScale = UIScreen.main.scale
        let screenNativeBounds = XCUIScreen.main.screenshot().image.size
        let screenShotWidth = screenNativeBounds.width * screenScale
        let screenShotHeight = screenNativeBounds.height * screenScale
        
        channelWidth = Double(screenShotWidth)  //Double(screenSize.width)
        channelHeight = Double(screenShotHeight) //Double(screenSize.height)
        
        var ratio:Double = 1.0
        ratio = channelHeight / Double(screenNativeBounds.height);
        
        deviceWidth = Double(channelWidth / ratio)
        deviceHeight = Double(channelHeight / ratio)
        
        self.resultElement["os"] = "ios"
        self.resultElement["driverVersion"] = self.driverVersion
        self.resultElement["systemName"] = model + " - " + osVersion
        self.resultElement["deviceWidth"] = deviceWidth
        self.resultElement["deviceHeight"] = deviceHeight
        self.resultElement["channelWidth"] = channelWidth
        self.resultElement["channelHeight"] = channelHeight
        self.resultElement["channelX"] = 0
        self.resultElement["channelY"] = 0
    } */
    
    func closeSocket() {
        Darwin.shutdown(self.tcpSocket, SHUT_RDWR)
        close(self.tcpSocket)
        //sendLogs(type: logType.INFO, message: "Close socket")
    }
    
    func checkTcpPortForListen(port: in_port_t) -> (Bool, descr: String) {
        
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return (false, "SocketCreationFailed, \(descriptionOfLastError())")
        }
        
        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))
        
        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            let details = descriptionOfLastError()
            release(socket: socketFileDescriptor)
            return (false, "\(port), BindFailed, \(details)")
        }
        if listen(socketFileDescriptor, SOMAXCONN ) == -1 {
            let details = descriptionOfLastError()
            release(socket: socketFileDescriptor)
            return (false, "\(port), ListenFailed, \(details)")
        }
        release(socket: socketFileDescriptor)
        self.tcpSocket = socketFileDescriptor
        return (true, "\(port) is free for use")
    }
    
    func release(socket: Int32) {
        Darwin.shutdown(socket, SHUT_RDWR)
        close(socket)
    }
    
    func descriptionOfLastError() -> String {
        return String.init(cString: (UnsafePointer(strerror(errno))))
    }
    
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 only
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                } else if name == "en1" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(1), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    override func tearDown() {
        self.closeSocket()
        super.tearDown()
    }
    
    func testExecuteCommand() {
        while continueExecution {}
    }
}

