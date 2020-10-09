//
//  UDPConnect.swift
//  atsDriver
//
//  Created by Caipture on 08/10/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Socket
import UIKit
import XCTest

class UDPConnect {

    static let current = UDPConnect()
    
    private var imgView: Data!
    
    private let udpThread = DispatchQueue(label: "udpQueue" + UUID().uuidString, qos: .userInitiated)
    
    func start() {
        udpThread.async {
            sendLogs(type: logType.INFO, message: "Starting UDP server on port: \(Device.current.screenCapturePort)")
            self.udpStart()
        }
    }
    
    func udpStart() {
        do {
            var data = Data()
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            
            repeat {
                let currentConnection = try socket.listen(forMessage: &data, on: Device.current.screenCapturePort)
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
        let device = Device.current
        UIGraphicsBeginImageContextWithOptions(CGSize(width: device.channelWidth, height: device.channelHeight), true, 0.60)
        XCUIScreen.main.screenshot().image.draw(in: CGRect(x: 0, y: 0, width: device.channelWidth, height: device.channelHeight))
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
}
