//
//  AppDelegate.swift
//  atsios
//
//  Copyright © 2019 ATSIOS. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    static func deviceScale() -> CGFloat {
        return UIScreen.main.scale
    }
}
