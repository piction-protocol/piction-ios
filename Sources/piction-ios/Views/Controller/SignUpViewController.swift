//
//  SignUpViewController.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import SafariServices

// MARK: - UIViewController
final class SignUpViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var checkboxImageView: UIImageView!
    @IBOutlet weak var agreeButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!

    @IBOutlet weak var loginIdInputView: DynamicInputView! {
        didSet {
            loginIdInputView.delegate = self
        }
    }
    @IBOutlet weak var emailInputView: DynamicInputView! {
        didSet {
            emailInputView.delegate = self
        }
    }
    @IBOutlet weak var passwordInputView: DynamicInputView! {
        didSet {
            passwordInputView.delegate = self
        }
    }
    @IBOutlet weak var passwordCheckInputView: DynamicInputView! {
        didSet {
            passwordCheckInputView.delegate = self
        }
    }
    @IBOutlet weak var nicknameInputView: DynamicInputView! {
        didSet {
            nicknameInputView.delegate = self
        }
    }
    @IBOutlet weak var agreementTextView: UITextView! {
        didSet {
            guard let termsURL = URL(string: "\(AppInfo.urlScheme)://terms") else { return }
            guard let privacyURL = URL(string: "\(AppInfo.urlScheme)://privacy") else { return }

            // 서비스 이용약관, 개인정보 처리방침의 폰트 색과 언더라인 추가하고 이동할 수 있도록 함
            let attributedStr = NSMutableAttributedString(string: LocalizationKey.str_agreement_text.localized())

            // 전체 텍스트
            attributedStr.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: attributedStr.mutableString.range(of: LocalizationKey.str_agreement_text.localized())) // 폰트사이즈
            attributedStr.addAttribute(.foregroundColor, value: UIColor.pictionGray, range: attributedStr.mutableString.range(of: LocalizationKey.str_agreement_text.localized())) // 폰트 색

            // 서비스 이용약관
            attributedStr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attributedStr.mutableString.range(of: LocalizationKey.str_terms.localized())) // 언더라인
            attributedStr.addAttribute(.foregroundColor, value: UIColor.pictionBlue, range: attributedStr.mutableString.range(of: LocalizationKey.str_terms.localized())) // 폰트 색
            attributedStr.addAttribute(.link, value: termsURL, range: attributedStr.mutableString.range(of: LocalizationKey.str_terms.localized())) // url 설정

            attributedStr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attributedStr.mutableString.range(of: LocalizationKey.str_privacy.localized())) // 언더라인
            attributedStr.addAttribute(.foregroundColor, value: UIColor.pictionBlue, range: attributedStr.mutableString.range(of: LocalizationKey.str_privacy.localized())) // 폰트 색
            attributedStr.addAttribute(.link, value: privacyURL, range: attributedStr.mutableString.range(of: LocalizationKey.str_privacy.localized())) // url 설정

            agreementTextView.textContainerInset = .zero // 기본 여백 제거

            // 상단 정렬
            let fittingSize = CGSize(width: agreementTextView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            let size = agreementTextView.sizeThatFits(fittingSize)
            let topOffset = (agreementTextView.bounds.size.height - size.height * agreementTextView.zoomScale) / 2
            let positiveTopOffset = max(0, topOffset)
            agreementTextView.contentInset.top = positiveTopOffset

            agreementTextView.attributedText = attributedStr
        }
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SignUpViewController: ViewModelBindable {
    typealias ViewModel = SignUpViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = SignUpViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            signUpBtnDidTap: signUpButton.rx.tap.asDriver().throttle(1), // 회원가입 버튼을 눌렀을 때
            loginIdTextFieldDidInput: loginIdInputView.inputTextField.rx.text.orEmpty.asDriver(), // login textfield를 입력했을 때
            emailTextFieldDidInput: emailInputView.inputTextField.rx.text.orEmpty.asDriver(), // email textfield를 입력했을 때
            passwordTextFieldDidInput: passwordInputView.inputTextField.rx.text.orEmpty.asDriver(), // password textfield를 입력했을 때
            passwordCheckTextFieldDidInput: passwordCheckInputView.inputTextField.rx.text.orEmpty.asDriver(), // password 확인 textfield를 입력했을 때
            nicknameTextFieldDidInput: nicknameInputView.inputTextField.rx.text.orEmpty.asDriver(), // 닉네임 textfield를 입력했을 때
            agreeBtnDidTap: agreeButton.rx.tap.asDriver() // 동의 버튼을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // 화면이 사라지기전에 viewModel에서 keyboard를 숨기고 disposed하기 위함
        output
            .viewWillDisappear
            .drive()
            .disposed(by: disposeBag)

        // 이미 로그인 되어있는데 딥링크 등을 통해 진입할 경우 화면을 닫고 토스트 출력
        output
            .userInfo
            .filter { $0.loginId != "" }
            .drive(onNext: { [weak self] _ in
                self?.dismiss(animated: true) {
                    Toast.showToast(LocalizationKey.msg_already_sign_in.localized())
                }
            })
            .disposed(by: disposeBag)

        // 회원가입 버튼이 활성/비활성화
        output
            .signUpBtnEnable
            .drive(onNext: { [weak self] in
                guard let isEnabled = self?.signUpButton.isEnabled else { return }
                if isEnabled {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOff")
                    self?.signUpButton.backgroundColor = .pictionLightGray
                    self?.signUpButton.setTitleColor(.pictionGray, for: .normal)
                } else {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOn")
                    self?.signUpButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                    self?.signUpButton.setTitleColor(.white, for: .normal)
                }
                self?.signUpButton.isEnabled = !isEnabled
            })
            .disposed(by: disposeBag)

        // 회원가입 완료 화면으로 push
        output
            .openSignUpComplete
            .map { .signUpComplete(loginId: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // keyboard가 나타나거나 사라질때 scrollView의 크기 조정
        output
            .keyboardWillChangeFrame
            .drive(onNext: { [weak self] changedFrameInfo in
                guard
                    let `self` = self,
                    let endFrame = changedFrameInfo.endFrame
                else { return }

                if endFrame.origin.y >= SCREEN_H {
                    self.scrollView.contentInset = .zero
                } else {
                    self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.size.height, right: 0)
                }

                UIView.animate(withDuration: changedFrameInfo.duration, animations: {
                    self.view.layoutIfNeeded()
                })
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 에러 메시지를 각 field 밑에 출력
        output
            .errorMsg
            .drive(onNext: { [weak self] error in
                guard
                    let field = error.field,
                    let message = error.message
                else { return }

                switch field {
                case "loginId":
                    self?.loginIdInputView.showError(message)
                case "email":
                    self?.emailInputView.showError(message)
                case "password":
                    self?.passwordInputView.showError(message)
                case "passwordCheck":
                    self?.passwordCheckInputView.showError(message)
                case "username":
                    self?.nicknameInputView.showError(message)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - IBAction
extension SignUpViewController {
    // 화면 tap 시 키보드 숨기기
    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

// MARK: - DynamicInputViewDelegate
extension SignUpViewController: DynamicInputViewDelegate {
    // 키보드의 return 키 눌렀을 때 다음 textField로 이동
    func returnKeyAction(_ textField: UITextField) {
        if textField === loginIdInputView.inputTextField {
            emailInputView.inputTextField.becomeFirstResponder()
        } else if textField === emailInputView.inputTextField {
            passwordInputView.inputTextField.becomeFirstResponder()
        } else if textField === passwordInputView.inputTextField {
            passwordCheckInputView.inputTextField.becomeFirstResponder()
        } else if textField === passwordCheckInputView.inputTextField {
            nicknameInputView.inputTextField.becomeFirstResponder()
        } else if textField === nicknameInputView.inputTextField {
            // 마지막 textField는 회원가입 버튼을 누르기 편하게 키보드를 닫음
            textField.resignFirstResponder()
        }
    }
}
