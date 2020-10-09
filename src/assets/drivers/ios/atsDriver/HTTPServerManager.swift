//
//  Server.swift
//  atsDriver
//
//  Created by Caipture on 07/10/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation
import Swifter

class HTTPServerManager {
    
    static let current = HTTPServerManager()
    
    private let server = HttpServer()
    private var controllers: [Routeable] = []

    private init() {}
    
    func startServer(_ port: in_port_t?) {
        do {
            let httpPort = try getAvailablePort(port)
            try server.start(httpPort)
            registerRouteControllers()
            
            sendLogs(type: logType.STATUS, message: "ATSDRIVER_DRIVER_HOST=\(getWiFiAddress()!):\(try server.port())")
            
            RunLoop.main.run()
        } catch {
            print("Server start error: \(error)")
            sendLogs(type: logType.STATUS, message: "** WIFI NOT CONNECTED **")
        }
    }
    
    func stopServer() {
        server.stop()
    }
    
    private func registerRouteControllers() {
        controllers.append(AppController())
        controllers.append(ButtonController())
        controllers.append(CaptureController())
        controllers.append(DriverController())
        controllers.append(ElementController())
        controllers.append(InfoController())
        controllers.append(ScreenshotController())
        controllers.append(PropertyController())
        
        controllers.forEach { server.POST["/\($0.name)"] = routeOnMain($0.handleRoutes(_:)) }
    }
    
    func routeOnMain(_ routingCall:@escaping ((Swifter.HttpRequest) -> Swifter.HttpResponse)) -> ((Swifter.HttpRequest) -> Swifter.HttpResponse) {
        return { (request: HttpRequest) -> HttpResponse in
            var response:HttpResponse = HttpResponse.internalServerError
            DispatchQueue.main.sync {
                response = routingCall(request)
            }
            return response
        }
    }
}

extension HTTPServerManager {
    
    enum SocketError: Error {
        case alreadyInUse(_ description: String)
        case notAvailable
    }
    
    private func checkPortAvailability(_ port: in_port_t) -> Bool {
        let (isFree, _) = checkTcpPortForListen(port: port)
        return isFree
    }
    
    private func getAvailablePort(_ port: in_port_t?) throws -> in_port_t {
        if let port = port {
            let (isFree, errorDescription) = checkTcpPortForListen(port: port)
            if isFree {
                return port
            } else {
                throw SocketError.alreadyInUse(errorDescription)
            }
        } else {
            for i: in_port_t in 8080..<65000 {
                if checkPortAvailability(i) {
                    return i
                }
            }
            
            throw SocketError.notAvailable
        }
    }
    
    private func checkTcpPortForListen(port: in_port_t) -> (Bool, descr: String) {
        
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
        return (true, "\(port) is free for use")
    }
    
    private func release(socket: Int32) {
        Darwin.shutdown(socket, SHUT_RDWR)
        close(socket)
    }
    
    private func descriptionOfLastError() -> String {
        return String.init(cString: (UnsafePointer(strerror(errno))))
    }
    
    private func getWiFiAddress() -> String? {
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
                if name == "en0" || name == "en1" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(Device.current.isSimulator ? 1 : 0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
}
