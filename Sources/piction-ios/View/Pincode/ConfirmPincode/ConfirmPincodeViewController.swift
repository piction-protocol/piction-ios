//
//  ConfirmPincodeViewController.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import LocalAuthentication

final class ConfirmPincodeViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var pincodeTextField: UITextField!
    @IBOutlet weak var pincode1View: UIView!
    @IBOutlet weak var pincode2View: UIView!
    @IBOutlet weak var pincode3View: UIView!
    @IBOutlet weak var pincode4View: UIView!
    @IBOutlet weak var pincode5View: UIView!
    @IBOutlet weak var pincode6View: UIView!

    private let changeComplete = PublishSubject<Void>()

    private func errorPopup() {
        let alert = UIAlertController(title: "PIN 재입력", message: "PIN 번호가 일치하지 않습니다.\n 다시 한 번 입력해주세요.", preferredStyle: .alert)

        let okAction = UIAlertAction(title: "확인", style: .default, handler: { action in
        })
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }

    private func registerAuthBioPopup() {
        let authContext = LAContext()
        if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {

            var authType = ""
            var description = ""
            switch authContext.biometryType {
            case .faceID:
                authType = "Face ID"
                description = "Face ID로 인증합니다."
            case .touchID:
                authType = "Touch ID"
                description = "Touch ID로 인증합니다."
            case .none:
                break
            }

            let alert = UIAlertController(title: authType, message: "\(authType)로 인증하시겠습니까?", preferredStyle: .alert)

            let okAction = UIAlertAction(title: "등록", style: .default, handler: { action in
                authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: description) { [weak self] (success, error) in
                    DispatchQueue.main.async {
                        if success {
                            print("인증 성공")
                            UserDefaults.standard.set(true, forKey: "isEnabledAuthBio")
                            self?.changeComplete.onNext(())
                        } else {
                            print("인증 실패")
                            if let error = error {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
            })
            alert.addAction(okAction)

            let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler : nil)
            alert.addAction(cancelAction)

            present(alert, animated: false, completion: nil)
        }
    }
}

extension ConfirmPincodeViewController: ViewModelBindable {

    typealias ViewModel = ConfirmPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = ConfirmPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(),
            changeComplete: changeComplete.asDriver(onErrorDriveWith: .empty())
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

                    if inputPincode == (self?.viewModel?.inputPincode ?? "") {
                        UserDefaults.standard.set(inputPincode, forKey: "pincode")
                        UserDefaults.standard.set(0, forKey: "pincodeErrorCount")
                        if !UserDefaults.standard.bool(forKey: "isEnabledAuthBio") {
                            self?.pincodeTextField.text = ""
                            self?.registerAuthBioPopup()
                        } else {
                            self?.changeComplete.onNext(())
                        }
                    } else {
                        self?.pincodeTextField.text = ""
                        self?.errorPopup()
                    }

                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}
