//
//  RegisterPincodeViewController.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class RegisterPincodeViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var pincodeTextField: UITextField!
    @IBOutlet weak var pincode1View: UIView!
    @IBOutlet weak var pincode2View: UIView!
    @IBOutlet weak var pincode3View: UIView!
    @IBOutlet weak var pincode4View: UIView!
    @IBOutlet weak var pincode5View: UIView!
    @IBOutlet weak var pincode6View: UIView!
    @IBOutlet weak var closeButton: UIBarButtonItem!

    private func openConfirmPincodeViewController(inputPincode: String) {
        let vc = ConfirmPincodeViewController.make(inputPincode: inputPincode)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openRecommendPopup() {
        let alertController = UIAlertController(title: "PIN 등록", message: "픽션 내 콘텐츠의 안전한 거래를 위해\nPIN 등록을 권장합니다.", preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: "계속", style: .default) { _ in
        }
        let confirmButton = UIAlertAction(title: "건너뛰기", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }
}

extension RegisterPincodeViewController: ViewModelBindable {

    typealias ViewModel = RegisterPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = RegisterPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarLine(false)
                self?.pincodeTextField.becomeFirstResponder()
            })
            .disposed(by: disposeBag)

        output
            .pincodeText
            .drive(onNext: { [weak self] inputPincode in
                switch inputPincode.count {
                case 0:
                    self?.pincode1View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode2View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode3View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode4View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode5View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode6View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                case 1:
                    self?.pincode1View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode2View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode3View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode4View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode5View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode6View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                case 2:
                    self?.pincode1View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode2View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode3View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode4View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode5View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode6View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                case 3:
                    self?.pincode1View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode2View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode3View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode4View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode5View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode6View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                case 4:
                    self?.pincode1View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode2View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode3View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode4View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode5View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.pincode6View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                case 5:
                    self?.pincode1View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode2View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode3View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode4View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode5View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode6View.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                case 6:
                    self?.pincode1View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode2View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode3View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode4View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode5View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincode6View.backgroundColor = UIColor(r: 26, g: 146, b: 255)
                    self?.pincodeTextField.text = ""
                    self?.openConfirmPincodeViewController(inputPincode: inputPincode)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .openRecommendPopup
            .drive(onNext: { [weak self] in
                self?.openRecommendPopup()
            })
            .disposed(by: disposeBag)

    }
}
