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

// MARK: - UIViewController
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

        // present 타입의경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: true, shadow: false)
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ConfirmPincodeViewController: ViewModelBindable {
    typealias ViewModel = ConfirmPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = ConfirmPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(), // pincode textfield에 입력했을 때
            changeComplete: changeComplete.asDriver(onErrorDriveWith: .empty()) // pincode가 정상적으로 변경되었을 때
        )
        
        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 키보드 출력
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.pincodeTextField.becomeFirstResponder()
            })
            .disposed(by: disposeBag)

        // pincode textfield에 값이 입력될 때
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

                    // 6자리 모두 입력되면 등록 시 입력한 pincode와 맞는지 확인
                    if inputedPincode == inputPincode {
                        // pincode error count 초기화
                        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(0, forKey: "pincodeErrorCount")
                        // 생채 인식 사용을 허용하지 않았으면 생채 인식을 사용할 것이냐는 팝업 출력
                        if !(UserDefaults(suiteName: "group.\(BUNDLEID)")?.bool(forKey: "isEnabledAuthBio") ?? false) {
                            self?.pincodeTextField.text = ""
                            self?.registerAuthBioPopup()
                        } else {
                            self?.changeComplete.onNext(())
                        }
                    } else { // pincode가 등록 시 입력한 pincode와 동일하지 않으면 에러 팝업 출력
                        self?.pincodeTextField.text = ""
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
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UITextFieldDelegate
extension ConfirmPincodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (string.count == 0) {
            return true
        }

        // 숫자만 입력 가능하도록 함
        if (textField == self.pincodeTextField) {
            let cs = CharacterSet(charactersIn: "0123456789")
            let filtered = string.components(separatedBy: cs).filter {  !$0.isEmpty }
            let str = filtered.joined(separator: "")

            return (string != str)
        }
        return true
    }
}

// MARK: - Private Method
extension ConfirmPincodeViewController {
    // pincode가 맞지 않다는 에러 팝업
    private func errorPopup() {
        let alert = UIAlertController(title: LocalizationKey.popup_title_pincode_confirm.localized(), message: LocalizationKey.msg_pincode_confirm_error.localized(), preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default)
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }

    // 생채 인식을 사용할 것이냐고 묻는 팝업
    private func registerAuthBioPopup() {
        let authContext = LAContext()
        if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {

            var authType = ""
            var description = ""
            switch authContext.biometryType {
            case .faceID:
                authType = "Face ID"
                description = LocalizationKey.str_authenticate_by_face_id.localized()
            case .touchID:
                authType = "Touch ID"
                description = LocalizationKey.str_authenticate_by_touch_id.localized()
            case .none:
                break
            @unknown default:
                break
            }

            let alert = UIAlertController(title: authType, message: LocalizationKey.str_authenticate_type.localized(with: authType), preferredStyle: .alert)

            let okAction = UIAlertAction(title: LocalizationKey.register.localized(), style: .default, handler: { action in
                authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: description) { [weak self] (success, error) in
                    DispatchQueue.main.async {
                        if success {
                            print("인증 성공")
                            // 생채인식을 사용하도록 함
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

            let cancelAction = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel, handler: { _ in
                self.changeComplete.onNext(())
            })
            alert.addAction(cancelAction)

            present(alert, animated: false, completion: nil)
        }
    }
}
