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

import Socket
import UIKit
import XCTest

class UDPConnect {

    static let current = UDPConnect()
    
    private var imgView: Data!
    private var socket: Socket!
    
    private let udpThread = DispatchQueue(label: "udpQueue" + UUID().uuidString, qos: .userInitiated)
    
    func start() {
        udpThread.async {
            sendLogs(type: .info, message: "Starting UDP server on port: \(Device.current.screenCapturePort)")
            self.udpStart()
        }
    }
    
    func stop() {
        socket.close()
    }
    
    private func udpStart() {
        do {
            var data = Data()
            socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            
            repeat {
                let currentConnection = try socket.listen(forMessage: &data, on: Device.current.screenCapturePort)
                self.addNewConnection(socket: socket, currentConnection: currentConnection)
            } while true
        } catch let error {
            guard let socketError = error as? Socket.Error else {
                sendLogs(type: .error, message: "Unexpected error...")
                return
            }
            sendLogs(type: .error, message: "Error on socket instance creation: \(socketError.description)")
        }
    }
    
    private func addNewConnection(socket: Socket, currentConnection: (bytesRead: Int, address: Socket.Address?)) {
        let bufferSize = 2000
        var offset = 0
        
        do {
            let workItem = DispatchWorkItem {
                self.refreshView()
            }
            
            DispatchQueue.init(label: "getImg").async(execute: workItem)
            workItem.wait()
            
            let img = self.imgView
            if (img != nil) {
                repeat {
                    let thisChunkSize = ((img!.count - offset) > bufferSize) ? bufferSize : (img!.count - offset);
                    var chunk = img!.subdata(in: offset..<offset + thisChunkSize)
                    offset += thisChunkSize
                    let uint32Offset = UInt32(offset - thisChunkSize)
                    let uint32RemainingData = UInt32(img!.count - offset)
                    
                    let offSetTable = UDPConnect.toByteArrary(value: uint32Offset)
                    let remainingDataTable = UDPConnect.toByteArrary(value: uint32RemainingData)
                    
                    chunk.insert(contentsOf: offSetTable + remainingDataTable, at: 0)
                    
                    try socket.write(from: chunk, to: currentConnection.address!)
                    
                } while (offset < img!.count);
            }
        }
        catch let error {
            guard let socketError = error as? Socket.Error else {
                sendLogs(type: .error, message: "Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                return
            }
            if continueExecution {
                sendLogs(type: .error, message: "Error reported by connection at \(socket.remoteHostname):\(socket.remotePort):\n \(socketError.description)")
            }
        }
        
    }
    
    private func refreshView() {
        let device = Device.current
        UIGraphicsBeginImageContextWithOptions(CGSize(width: device.channelWidth, height: device.channelHeight), true, 0.60)
        XCUIScreen.main.screenshot().image.draw(in: CGRect(x: 0, y: 0, width: device.channelWidth, height: device.channelHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.imgView = (newImage ?? UIImage()).jpegData(compressionQuality: 0.2)
    }
    
    private static func toByteArrary<T>(value: T)  -> [UInt8] where T: UnsignedInteger, T: FixedWidthInteger{
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
