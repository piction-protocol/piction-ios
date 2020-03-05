//
//  CheckPincodeViewController.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import LocalAuthentication

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

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

        // present 타입의경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: true, shadow: false)
    }

    func hideExtensionWithCompletionHandler(completion: @escaping (Bool) -> Void) {
        UIView.animate(withDuration: 0.20, animations: {
            self.navigationController!.view.transform = CGAffineTransform(translationX: 0, y: self.navigationController!.view.frame.size.height)
        }, completion: completion)
    }

    private func errorPopup() {
        let errorCount = (UserDefaults(suiteName: "group.\(BUNDLEID)")?.integer(forKey: "pincodeErrorCount") ?? 0) + 1
        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(errorCount, forKey: "pincodeErrorCount")

        var message: String {
            if errorCount >= 10 {
                return LocalizationKey.msg_pincode_error_end.localized()
            } else {
                return "\(LocalizationKey.msg_pincode_error.localized())\n(\(errorCount)/10)"
            }
        }

        let alert = UIAlertController(title: LocalizationKey.popup_title_pincode_sign_out.localized(), message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default, handler: { [weak self] action in
            if errorCount >= 10 {
                self?.signout.onNext(())
            }
        })
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }

    private func authSuccess() {
        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(0, forKey: "pincodeErrorCount")

        let vc = CreatePostViewController.make(context: self.extensionContext)
        self.navigationController?.setViewControllers([vc], animated: true)
    }

    func auth() {
        let authContext = LAContext()
        if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            var description = ""
            switch authContext.biometryType {
            case .faceID:
                description = LocalizationKey.str_authenticate_by_face_id.localized()
            case .touchID:
                description = LocalizationKey.str_authenticate_by_touch_id.localized()
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

                self?.closeButton.isEnabled = true
                self?.closeButton.title = LocalizationKey.cancel.localized()

                if UserDefaults(suiteName: "group.\(BUNDLEID)")?.bool(forKey: "isEnabledAuthBio") ?? false {
                    self?.auth()
                }
                FirebaseManager.screenName("공유_PIN인증")
            })
            .disposed(by: disposeBag)

        output
            .pincodeText
            .drive(onNext: { [weak self] inputPincode in
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
                    self?.pincodeTextField.text = ""
                    if KeychainManager.get(key: .pincode) == inputPincode {
                        self?.authSuccess()
                    } else {
                        self?.errorPopup()
                    }
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.hideExtensionWithCompletionHandler(completion: { [weak self] (Bool) -> Void in
                self?.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
                })
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
