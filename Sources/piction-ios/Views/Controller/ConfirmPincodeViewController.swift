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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: true, shadow: false)
    }

    private func errorPopup() {
        let alert = UIAlertController(title: LocalizedStrings.popup_title_pincode_confirm.localized(), message: LocalizedStrings.msg_pincode_confirm_error.localized(), preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizedStrings.confirm.localized(), style: .default, handler: { action in
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
                description = LocalizedStrings.str_authenticate_by_face_id.localized()
            case .touchID:
                authType = "Touch ID"
                description = LocalizedStrings.str_authenticate_by_touch_id.localized()
            case .none:
                break
            }

            let alert = UIAlertController(title: authType, message: LocalizedStrings.str_authenticate_type.localized(with: authType), preferredStyle: .alert)

            let okAction = UIAlertAction(title: LocalizedStrings.register.localized(), style: .default, handler: { action in
                authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: description) { [weak self] (success, error) in
                    DispatchQueue.main.async {
                        if success {
                            print("인증 성공")
                            UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(true, forKey: "isEnabledAuthBio")
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

            let cancelAction = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel, handler: { [weak self] _ in
                self?.changeComplete.onNext(())
            })
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
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.pincodeTextField.becomeFirstResponder()
                FirebaseManager.screenName("PIN재입력")
            })
            .disposed(by: disposeBag)

        output
            .inputPincode
            .drive(onNext: { [weak self] (inputedPincode, inputPincode) in
                switch inputPincode.count {
                case 0:
                    self?.pincode1View.backgroundColor = .pictionLightGray
                    self?.pincode2View.backgroundColor = .pictionLightGray
                    self?.pincode3View.backgroundColor = .pictionLightGray
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 1:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionLightGray
                    self?.pincode3View.backgroundColor = .pictionLightGray
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 2:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionLightGray
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 3:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 4:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionBlue
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 5:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionBlue
                    self?.pincode5View.backgroundColor = .pictionBlue
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 6:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionBlue
                    self?.pincode5View.backgroundColor = .pictionBlue
                    self?.pincode6View.backgroundColor = .pictionBlue

                    if inputedPincode == inputPincode {
                        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(0, forKey: "pincodeErrorCount")
                        if !(UserDefaults(suiteName: "group.\(BUNDLEID)")?.bool(forKey: "isEnabledAuthBio") ?? false) {
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

extension ConfirmPincodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (string.count == 0) {
            return true
        }

        if (textField == self.pincodeTextField) {
            let cs = CharacterSet(charactersIn: "0123456789")
            let filtered = string.components(separatedBy: cs).filter {  !$0.isEmpty }
            let str = filtered.joined(separator: "")

            return (string != str)
        }
        return true
    }
}
