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
    var resultElement: [String: Any] = [:]
    var thread: Thread! = nil
    var connectedSockets = [Int32: Socket]()
    var imgView: Data? = nil
    var tcpSocket = socket(AF_INET, SOCK_STREAM, 0)
    let bluetoothName = UIDevice.current.name
    
    struct Settings: Decodable {
        let apps: [String]
        let customPort: String?
    }
    
    override func setUp() {
                
        super.setUp()
        continueAfterFailure = true
        
        udpPort = Int.random(in: 32000..<64000)
        sendLogs(type: logType.STATUS, message: "UDP PORT for " + self.bluetoothName + " = " + String(udpPort))
        
        udpThread.async {
            sendLogs(type: logType.INFO, message: "Starting UDP server on port: \(udpPort)")
            self.udpStart()
        }
        
        var customPort:String?

        let jsonURL = Bundle(for: atsDriver.self).url(forResource: "Settings", withExtension: "json")!
        let jsonData = try! Data(contentsOf: jsonURL)
        let jsonDecoder = JSONDecoder()
        let settings = try! jsonDecoder.decode(Settings.self, from: jsonData)
        
        customPort = settings.customPort
        appsInstalled = settings.apps
        
        sendLogs(type: logType.INFO, message: "Fixed port defined: \(String(describing: customPort))")
        
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
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        }
        
        if let customPort = customPort {
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
        
        sendLogs(type: logType.INFO, message: "Start HTTP server : \(port)")
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
                    sendLogs(type: logType.INFO, message: "Get screenshot informations")
                    self.screenShotThread.sync {
                        sendBody(screenshot)
                        // sendLogs(type: logType.INFO, message: "Screenshot sended with \(bytes.count) bytes")
                        usleep(1000000)
                    }
                    self.screenShotThread.sync {
                        sendBody(Data())
                        sendLogs(type: logType.INFO, message: "Flush screenshot thread")
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
    
    func closeSocket() {
        Darwin.shutdown(self.tcpSocket, SHUT_RDWR)
        close(self.tcpSocket)
        sendLogs(type: logType.INFO, message: "Close socket")
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
                print(name)
                if name == "en0" || name == "en1" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(UIDevice.isSimulator ? 1 : 0), NI_NUMERICHOST)
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

