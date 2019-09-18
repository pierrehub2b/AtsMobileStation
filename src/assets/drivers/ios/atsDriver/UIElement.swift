//
//  UIElement.swift
//  atsDriver
//
//  Created by Laura Chiudini on 27/08/2019.
//  Copyright © 2019 CAIPTURE. All rights reserved.
//

import Foundation

struct UIElement: Codable {
    let id: String
    let tag: String
    let clickable: Bool
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var children: [UIElement]?
    var attributes: [String:String]
    let channelY: Double?
    let channelHeight: Double?
}
