//
//  GetEnumValuesFunctions.swift
//  atsDriver
//
//  Created by Laura Chiudini on 27/08/2019.
//  Copyright © 2019 CAIPTURE. All rights reserved.
//

import Foundation

func getStateStringValue(rawValue: UInt) -> String {
    switch rawValue {
    case 0:
        return "unknown"
    case 1:
        return "notRunning"
    case 2:
        return "runningBackgroundSuspended"
    case 3:
        return "runningBackground"
    case 4:
        return "runningForeground"
    default:
        return "unknown"
    }
}
