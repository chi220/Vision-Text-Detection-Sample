//
//  SessionBuilder.swift
//  Vision-Text-Detection-Sample
//
//  Created by kawaharadai on 2019/07/12.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import AVFoundation

final class SessionBuilder {

    static func makeCaptureSession() -> AVCaptureSession? {
        guard let defaultDevice = AVCaptureDevice.default(for: .video) else {
            print("video用デバイスの生成に失敗")
            return nil
        }

        if let _ = try? defaultDevice.lockForConfiguration() {
            if defaultDevice.isFocusModeSupported(.continuousAutoFocus) {
                defaultDevice.focusMode = .continuousAutoFocus
                defaultDevice.autoFocusRangeRestriction = .near
            }
            defaultDevice.unlockForConfiguration()
        }

        guard let input = try? AVCaptureDeviceInput(device: defaultDevice) else {
            print("AVCaptureDeviceInputの生成に失敗")
            return nil
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard session.canAddInput(input) else {
            print("inputがsessionで使用できない")
            return nil
        }

        session.addInput(input)

        session.commitConfiguration()

        return session
    }

}

