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

import UIKit
import XCTest
import Network

class UDPConnect {
    
    static let current = UDPConnect()
    
    private var listener: NWListener!
    private var connection: NWConnection!
            
    private let udpThread = DispatchQueue(label: "udpQueue" + UUID().uuidString, qos: .userInitiated)
    
    func stop() {
        listener?.cancel()
        connection?.cancel()
    }
    
    func start() {
        do {
            let port = UInt16(Device.current.screenCapturePort)
            listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        listener.newConnectionHandler = { conn in
            self.connection?.cancel()
            self.connection = conn
            
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    self.receive(on: conn)
                case .failed(let error):
                    print("conn failed : \(error)")
                default:
                    break
                }
            }
            
            conn.start(queue: self.udpThread)
        }
        
        listener.start(queue: DispatchQueue.main)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receiveMessage { (_, _, _, _) in

            guard let nextFrame = self.nextFrame() else {
                self.receive(on: connection)
                return
            }

            self.sendFrame(nextFrame, on: connection)
        }
    }
    
    private let packetSize = 2000

    private func sendFrame(_ frame: Data, on connection: NWConnection) {
        var datagramArray: [Data] = []
        var offSet = 0

        repeat {
            let datagramSize = min(packetSize, frame.count - offSet)
            var datagram = frame.subdata(in: offSet..<offSet + datagramSize)
            
            let offsetIndex = UInt32(offSet).toByteArray()
            
            offSet += datagramSize
            let remainingDataCount = UInt32(frame.count - offSet).toByteArray()
            
            datagram.insert(contentsOf: offsetIndex + remainingDataCount, at: 0)
            
            datagramArray.append(datagram)
            
        } while offSet < frame.count
                
        connection.batch {
            datagramArray.forEach { connection.send(content: $0, completion: NWConnection.SendCompletion.contentProcessed { _ in }) }
        }
        
        receive(on: connection)
    }
    
    private func nextFrame() -> Data? {
        let device = Device.current
        let channelSize = CGSize(width: device.channelWidth, height: device.channelHeight)

        UIGraphicsBeginImageContextWithOptions(channelSize, true, 0.60)
        XCUIScreen.main.screenshot().image.draw(in: CGRect(origin: .zero, size: channelSize))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image?.jpegData(compressionQuality: 0.2)
    }
}

extension UInt32 {
    
    func toByteArray() -> [UInt8] {
        var bigEndian = self.bigEndian
        let count = MemoryLayout<Self>.size
        let bytePtr = withUnsafePointer(to: &bigEndian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return Array(bytePtr)
    }
}
