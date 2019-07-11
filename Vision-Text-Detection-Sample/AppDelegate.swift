//
//  AppDelegate.swift
//  Vision-Text-Detection-Sample
//
//  Created by kawaharadai on 2019/07/12.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
        guard let session = SessionBuilder.makeCaptureSession() else {
            fatalError()
        }
        window.rootViewController = CameraViewController(session: session)
        self.window = window
        self.window?.makeKeyAndVisible()
        return true
    }

}

