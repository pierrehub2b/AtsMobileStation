//
//  File.swift
//  atsDriver
//
//  Created by Utilisateur on 02/04/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation

enum logType: String {
    case STATUS = "STATUS"
    case INFO = "INFO"
    case ERROR = "ERROR"
    case WARNING = "WARNING"
}

func sendLogs(type:logType, message:String) {
    print("[\(type)] \(message)\n")
}
