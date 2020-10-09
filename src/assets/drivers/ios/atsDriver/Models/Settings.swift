//
//  Settings.swift
//  atsDriver
//
//  Created by Caipture on 06/10/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import Foundation

struct Settings: Decodable {
    let apps: [String]
    let customPort: in_port_t?
}
