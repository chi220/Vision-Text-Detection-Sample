//
//  CameraViewController.swift
//  Vision-Text-Detection-Sample
//
//  Created by kawaharadai on 2019/07/12.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import AVFoundation
import UIKit

final class CameraViewController: UIViewController {

    private let session: AVCaptureSession
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let output: AVCapturePhotoOutput = .init()
    private let sessionQueue = DispatchQueue(label: "sessionQueue", attributes: .concurrent)
    private var capturePhotoSettings: AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.flashMode = .auto
        return settings
    }

    init(session: AVCaptureSession) {
        self.session = session
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(nibName: String(describing: CameraViewController.self), bundle: .main)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if CameraAccessPermission.needsToRequestAccess {
            CameraAccessPermission.requestAccess { (isAccess) in
                guard isAccess else { fatalError() }
            }
            setup()
        } else {
            setup()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.frame
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }

    private func setup() {
        if session.canAddOutput(output) {
            session.addOutput(output)
            setupCamera()
        } else {
            print("set error View")
        }
    }

    private func setupCamera() {
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)

        guard !session.isRunning else { return }

        startSession()
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

}
