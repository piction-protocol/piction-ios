//
//  QRCodeScannerViewController.swift
//  PictionSDK
//
//  Created by jhseo on 30/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa
import ViewModelBindable

final class QRCodeScannerViewController: UIViewController {
    var disposeBag = DisposeBag()

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var closeButton: UIBarButtonItem!

    private let qrCodeData = PublishSubject<String>()

    override func viewDidLoad() {
        super.viewDidLoad()

        initialAVCaptureSession()
    }

    private func openSendDonationViewController(loginId: String) {
        let vc = SendDonationViewController.make(loginId: loginId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openErrorPopup(message: String) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: "확인", style: .default, handler: { [weak self] _ in
            self?.captureSession.startRunning()
        })

        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }
}

extension QRCodeScannerViewController: ViewModelBindable {
    typealias ViewModel = QRCodeScannerViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = QRCodeScannerViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            qrCodeDataDidLoad: qrCodeData.asDriver(onErrorDriveWith: .empty()),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                if !(self?.captureSession?.isRunning ?? false) {
                    self?.captureSession.startRunning()
                }
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                if !(self?.captureSession?.isRunning ?? true) {
                    self?.captureSession.stopRunning()
                }
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .openSendDonationViewController
            .drive(onNext: { [weak self] loginId in
                self?.dismiss(animated: true, completion: { [weak self] in
                    self?.openSendDonationViewController(loginId: loginId)
                })
            })
            .disposed(by: disposeBag)

        output
            .openErrorPopup
            .drive(onNext: { [weak self] message in
                self?.openErrorPopup(message: message)
            })
            .disposed(by: disposeBag)
    }
}

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func initialAVCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = preview.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        preview.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
            self.qrCodeData.onNext(stringValue)
        }

//        dismiss(animated: true)
    }

    func found(code: String) {
        print(code)
    }
}
