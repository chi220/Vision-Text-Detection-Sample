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

    /*
     VisionFrameworkから返されるframeをUIKitで扱う用に変換する
     Visionから返ってくる値の座標系は原点 (0, 0) が画像左下、正の方向が画像右上となっている
     UIKitの座標系は原点 (0, 0) が左上、正の方向が右下なので、UIKit用にマッピングする際はY軸を反転させる
     */
    func convertRect(fromRect: CGRect, toViewRect: UIView) -> CGRect {
        var toRect = CGRect()
        toRect.size.width = fromRect.size.width * toViewRect.frame.size.width
        toRect.size.height = fromRect.size.height * toViewRect.frame.size.height
        toRect.origin.y =  (toViewRect.frame.height) - (toViewRect.frame.height * fromRect.origin.y)
        toRect.origin.y  = toRect.origin.y - toRect.size.height
        toRect.origin.x =  fromRect.origin.x * toViewRect.frame.size.width
        return toRect
    }

    /// 文字列ごとの枠線つける
    ///
    /// - Parameter box: 文字列の短形情報
    func highlightWord(box: VNTextObservation) {
        let outline = CALayer()
        outline.frame = convertRect(fromRect: box.boundingBox, toViewRect: captureImageView)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        captureImageView.layer.addSublayer(outline)
    }


    /// 一文字ごとの枠線つける
    ///
    /// - Parameter box: 文字ごとの短形情報
    func highlightLetters(box: VNRectangleObservation) {
        let outline = CALayer()
        outline.frame = convertRect(fromRect: box.boundingBox, toViewRect: captureImageView)
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
