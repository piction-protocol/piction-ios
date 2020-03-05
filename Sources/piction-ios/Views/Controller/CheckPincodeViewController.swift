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

// MARK: - CheckPincodeDelegate
protocol CheckPincodeDelegate: class {
    func authSuccess()
}

// MARK: - UIViewController
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

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CheckPincodeViewController: ViewModelBindable {
    typealias ViewModel = CheckPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = CheckPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(), // pincode textfield에 입력했을 때
            closeBtnDidTap: closeButton.rx.tap.asDriver(), // 닫기 버튼을 눌렀을 때
            signout: signout.asDriver(onErrorDriveWith: .empty()) // 로그아웃이 필요할 때
        )
        
        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                // 키보드 출력
                self?.pincodeTextField.becomeFirstResponder()

                // 생채 인증 설정하였으면 생채 인증으로 인증함
                if UserDefaults(suiteName: "group.\(BUNDLEID)")?.bool(forKey: "isEnabledAuthBio") ?? false {
                    self?.auth()
                }
            })
            .disposed(by: disposeBag)

        // 닫기 버튼 스타일 (앱 최초 진입 시에는 닫기버튼을 보여주지 않음)
        output
            .closeBtnStyle
            .drive(onNext: { [weak self] style in
                // 앱 최초 진입이 아닌 경우에만 취소 버튼 출력
                if style != .initial {
                    self?.closeButton.isEnabled = true
                    self?.closeButton.title = LocalizationKey.cancel.localized()
                }
            })
            .disposed(by: disposeBag)

        // Pincode 입력 시 UI 변경 및 6자리 입력 시 저장된 Pincode와 비교
        output
            .inputPincode
            .drive(onNext: { [weak self] (pincode, inputPincode) in
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
                    if pincode == inputPincode {
                        // 저장된 pincode가 맞으면 인증 진행
                        self?.authSuccess()
                    } else {
                        // pincode 오류 시 에러 팝업 출력
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
extension CheckPincodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (string.count == 0) {
            return true
        }

        // 숫자만 입력되도록 함
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
extension CheckPincodeViewController {
    // Pincode 오류 시 에러 팝업
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

        let okAction = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default, handler: { action in
            // errorcount가 10이상이면 로그아웃
            if errorCount >= 10 {
                self.signout.onNext(())
            }
        })
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }

    private func authSuccess() {
        // 인증 성공하여 에러 카운트 초기화
        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(0, forKey: "pincodeErrorCount")

        if self.viewModel?.style == .initial { // 앱 진입 시 인증하는 화면이었다면 TabBarViewController를 출력
            self.dismiss(animated: true)
            let rootView = TabBarController()
            UIApplication.shared.keyWindow?.rootViewController = rootView
        } else if self.viewModel?.style == .check { // 인증을 위한 화면이었다면 delegate의 authSuccess 호출
            self.dismiss(animated: true, completion: { [weak self] in
                self?.delegate?.authSuccess()
            })
        } else { // pincode를 변경하기 위한 인증 화면이었다면 pincode 등록화면으로 push
            self.openView(type: .registerPincode, openType: .push)
        }
    }

    // faceID가 있으면 faceId 사용, touchID가 있으면 touchID 사용
    private func auth() {
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
            @unknown default:
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
        } else {
            self.authSuccess()
        }
    }
}
