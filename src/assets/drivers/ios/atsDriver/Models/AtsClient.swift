//
//  AtsClient.swift
//  atsDriver
//
//  Created by Anthony D'HIERRE on 19/05/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation

struct AtsClient {
    
    static var current: AtsClient?
    
    let token: String
    let userAgent: String
    let ipAddress: String
}
