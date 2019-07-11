//
//  CameraAccessPermission.swift
//  Vision-Text-Detection-Sample
//
//  Created by kawaharadai on 2019/07/12.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import AVFoundation

final class CameraAccessPermission {

    private static var canAccess: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    static var needsToRequestAccess: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
    }

    static func requestAccess(completion handler: @escaping (Bool) -> Void) {
        guard needsToRequestAccess else {
            handler(canAccess)
            return
        }
        AVCaptureDevice.requestAccess(for: .video, completionHandler: handler)
    }

}
