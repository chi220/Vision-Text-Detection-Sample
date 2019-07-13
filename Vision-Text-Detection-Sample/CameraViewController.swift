//
//  CameraViewController.swift
//  Vision-Text-Detection-Sample
//
//  Created by kawaharadai on 2019/07/12.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

final class CameraViewController: UIViewController {

    @IBOutlet weak var captureSessionView: UIView!
    @IBOutlet weak var reshootButton: UIButton!
    @IBOutlet weak var shootButton: UIButton!
    @IBOutlet weak var analysisButton: UIButton!

    private let session: AVCaptureSession
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let output: AVCapturePhotoOutput = .init()
    private let sessionQueue = DispatchQueue(label: "sessionQueue", attributes: .concurrent)
    private var capturePhotoSettings: AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.flashMode = .auto
        return settings
    }
    private var capturePhoto: AVCapturePhoto?
    private var requests = [VNRequest]()
    private var captureImageView: UIImageView!

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
        previewLayer.frame = captureSessionView.frame
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }

    private func setup() {
        if session.canAddOutput(output) {
            session.addOutput(output)
            setupCamera()
            setupTextDetection()
        } else {
            print("set error View")
        }
    }

    private func setupCamera() {
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        captureSessionView.layer.addSublayer(previewLayer)

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

    func setupTextDetection() {
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: self.detectTextHandler)
        textRequest.reportCharacterBoxes = true
        self.requests = [textRequest]
    }

    func detectTextHandler(request: VNRequest, error: Error?) {
        guard let results = request.results else {
            print("no result")
            return
        }

        let boxs = results.compactMap { $0 as? VNTextObservation }
        boxs.forEach { [weak self] in
            self?.highlightWord(box: $0)
            if let characterBoxes = $0.characterBoxes {
                characterBoxes.forEach {
                    self?.highlightLetters(box: $0)
                }
            }
        }
    }

    /// 文字列ごとの枠線つける
    ///
    /// - Parameter box: 文字列の短形情報
    func highlightWord(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else {
            return
        }

        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0

        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }

        let xCord = maxX * captureSessionView.frame.size.width
        let yCord = (1 - minY) * captureSessionView.frame.size.height
        let width = (minX - maxX) * captureSessionView.frame.size.width
        let height = (minY - maxY) * captureSessionView.frame.size.height

        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor

        captureImageView.layer.addSublayer(outline)
    }


    /// 一文字ごとの枠線つける
    ///
    /// - Parameter box: 文字ごとの短形情報
    func highlightLetters(box: VNRectangleObservation) {
        let xCord = box.topLeft.x * captureSessionView.frame.size.width
        let yCord = (1 - box.topLeft.y) * captureSessionView.frame.size.height
        let width = (box.topRight.x - box.bottomLeft.x) * captureSessionView.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * captureSessionView.frame.size.height

        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.blue.cgColor

        captureImageView.layer.addSublayer(outline)
    }

    @IBAction func didTapShoot(_ sender: UIButton) {
        output.capturePhoto(with: capturePhotoSettings, delegate: self)
    }

    @IBAction func didTapReshoot(_ sender: UIButton) {
        captureSessionView.removeSubView()
        startSession()
    }
    
    @IBAction func didTapAnalysis(_ sender: UIButton) {
        guard let photo = capturePhoto,
            let photoData = photo.fileDataRepresentation(),
            let image = UIImage(data: photoData),
            let ciImage = CIImage(image: image) else {
            return
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])

        do {
            try imageRequestHandler.perform(requests)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        capturePhoto = photo

        let photoImage: () -> (UIImage?) = { [weak self] in
            guard let self = self else { return nil }
            if let photoData = photo.fileDataRepresentation(), let photoImage = UIImage(data: photoData) {
                return photoImage
            } else if let screenShotView = self.captureSessionView.snapshotView(afterScreenUpdates: true) {
                return screenShotView.image
            } else {
                return nil
            }
        }

        if let image = photoImage() {
            captureImageView = UIImageView(image: image)
            captureImageView.contentMode = .scaleAspectFill
            captureImageView.frame = captureSessionView.frame
            captureSessionView.addSubview(captureImageView)
            stopSession()
        } else {
            fatalError()
        }
    }
}

private extension UIView {
    func removeSubView() {
        subviews.forEach {
            $0.removeFromSuperview()
        }
    }
    var image: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
