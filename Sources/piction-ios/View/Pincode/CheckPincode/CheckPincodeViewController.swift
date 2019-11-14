//
//  CheckPincodeViewController.swift
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
import PictionSDK

protocol CheckPincodeDelegate: class {
    func authSuccess()
}

final class CheckPincodeViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var pincodeTextField: UITextField!
    @IBOutlet weak var pincode1View: UIView!
    @IBOutlet weak var pincode2View: UIView!
    @IBOutlet weak var pincode3View: UIView!
    @IBOutlet weak var pincode4View: UIView!
    @IBOutlet weak var pincode5View: UIView!
    @IBOutlet weak var pincode6View: UIView!
    @IBOutlet weak var closeButton: UIBarButtonItem!

    weak var delegate: CheckPincodeDelegate?

    private let signout = PublishSubject<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: true, shadow: false)
    }

    private func errorPopup() {
        let errorCount = (UserDefaults(suiteName: "group.\(BUNDLEID)")?.integer(forKey: "pincodeErrorCount") ?? 0) + 1
        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(errorCount, forKey: "pincodeErrorCount")

        var message: String {
            if errorCount >= 10 {
                return LocalizedStrings.msg_pincode_error_end.localized()
            } else {
                return "\(LocalizedStrings.msg_pincode_error.localized())\n(\(errorCount)/10)"
            }
        }

        let alert = UIAlertController(title: LocalizedStrings.popup_title_pincode_sign_out.localized(), message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizedStrings.confirm.localized(), style: .default, handler: { [weak self] action in
            if errorCount >= 10 {
                self?.signout.onNext(())
            }
        })
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }

    private func openRegisterPincodeViewController() {
        let vc = RegisterPincodeViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func authSuccess() {
        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(0, forKey: "pincodeErrorCount")
        if self.viewModel?.style == .initial {
            self.dismiss(animated: true)
            let rootView = TabBarController()
            UIApplication.shared.keyWindow?.rootViewController = rootView
        } else if self.viewModel?.style == .check {
            self.dismiss(animated: true, completion: { [weak self] in
                self?.delegate?.authSuccess()
            })
        } else {
            self.openRegisterPincodeViewController()
        }
    }

    func auth() {
        let authContext = LAContext()
        if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            var description = ""
            switch authContext.biometryType {
            case .faceID:
                description = LocalizedStrings.str_authenticate_by_face_id.localized()
            case .touchID:
                description = LocalizedStrings.str_authenticate_by_touch_id.localized()
            case .none:
                break
            }

            authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: description) { [weak self] (success, error) in
                DispatchQueue.main.async {
                    if success {
                        print("인증 성공")
                        self?.authSuccess()
                    } else {
                        print("인증 실패")
                        if let error = error {
                            print(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}

extension CheckPincodeViewController: ViewModelBindable {

    typealias ViewModel = CheckPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = CheckPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver(),
            signout: signout.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] style in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.pincodeTextField.becomeFirstResponder()

                if style == .change || style == .check {
                    self?.closeButton.isEnabled = true
                    self?.closeButton.title = LocalizedStrings.cancel.localized()
                }
                if UserDefaults(suiteName: "group.\(BUNDLEID)")?.bool(forKey: "isEnabledAuthBio") ?? false {
                    self?.auth()
                }
                FirebaseManager.screenName("PIN인증")
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
                    if KeychainManager.get(key: "pincode") == inputPincode {
                        self?.authSuccess()
                    } else {
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

extension CheckPincodeViewController: UITextFieldDelegate {
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
