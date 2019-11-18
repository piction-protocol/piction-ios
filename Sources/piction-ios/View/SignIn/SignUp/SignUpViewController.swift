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
            let attributedStr: NSMutableAttributedString = NSMutableAttributedString(string: LocalizedStrings.str_agreement_text.localized())

            guard let termsURL = URL(string: "\(AppInfo.urlScheme)://terms") else { return }
            guard let privacyURL = URL(string: "\(AppInfo.urlScheme)://privacy") else { return }

            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 14), range: attributedStr.mutableString.range(of: LocalizedStrings.str_agreement_text.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(r: 191, g: 191, b: 191), range: attributedStr.mutableString.range(of: LocalizedStrings.str_agreement_text.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(r: 191, g: 191, b: 191), range: attributedStr.mutableString.range(of: LocalizedStrings.str_agreement_text.localized()))

            attributedStr.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attributedStr.mutableString.range(of: LocalizedStrings.str_terms.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(r: 26, g: 146, b: 255), range: attributedStr.mutableString.range(of: LocalizedStrings.str_terms.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.link, value: termsURL, range: attributedStr.mutableString.range(of: LocalizedStrings.str_terms.localized()))

            attributedStr.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attributedStr.mutableString.range(of: LocalizedStrings.str_privacy.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(r: 26, g: 146, b: 255), range: attributedStr.mutableString.range(of: LocalizedStrings.str_privacy.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.link, value: privacyURL, range: attributedStr.mutableString.range(of: LocalizedStrings.str_privacy.localized()))


            agreementTextView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            let fittingSize = CGSize(width: agreementTextView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            let size = agreementTextView.sizeThatFits(fittingSize)
            let topOffset = (agreementTextView.bounds.size.height - size.height * agreementTextView.zoomScale) / 2
            let positiveTopOffset = max(0, topOffset)
            agreementTextView.contentInset.top = positiveTopOffset

            agreementTextView.attributedText = attributedStr
        }
    }

    private func openSignUpComplete(loginId: String) {
        let vc = SignUpCompleteViewController.make(loginId: loginId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension SignUpViewController: ViewModelBindable {

    typealias ViewModel = SignUpViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = SignUpViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            signUpBtnDidTap: signUpButton.rx.tap.asDriver().throttle(1),
            loginIdTextFieldDidInput: loginIdInputView.inputTextField.rx.text.orEmpty.asDriver(),
            emailTextFieldDidInput: emailInputView.inputTextField.rx.text.orEmpty.asDriver(),
            passwordTextFieldDidInput: passwordInputView.inputTextField.rx.text.orEmpty.asDriver(),
            passwordCheckTextFieldDidInput: passwordCheckInputView.inputTextField.rx.text.orEmpty.asDriver(),
            nicknameTextFieldDidInput: nicknameInputView.inputTextField.rx.text.orEmpty.asDriver(),
            agreeBtnDidTap: agreeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tabBarController?.tabBar.isHidden = true
                FirebaseManager.screenName("회원가입")
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                if userInfo.loginId != "" {
                    self?.dismiss(animated: true, completion: {
                        Toast.showToast(LocalizedStrings.msg_already_sign_in.localized())
                    })
                }
            })
            .disposed(by: disposeBag)

        output
            .signUpBtnEnable
            .drive(onNext: { [weak self] _ in
                guard let isEnabled = self?.signUpButton.isEnabled else {
                    return
                }
                if isEnabled {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOff")
                    self?.signUpButton.backgroundColor = UIColor(r: 242, g: 242, b: 242)
                    self?.signUpButton.setTitleColor(UIColor(r: 191, g: 191, b: 191), for: .normal)
                } else {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOn")
                    self?.signUpButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                    self?.signUpButton.setTitleColor(.white, for: .normal)
                }
                self?.signUpButton.isEnabled = !isEnabled
            })
            .disposed(by: disposeBag)

        output
            .openSignUpComplete
            .drive(onNext: { [weak self] in
                let loginId = self?.loginIdInputView.inputTextField.text ?? ""
                self?.openSignUpComplete(loginId: loginId)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .errorMsg
            .drive(onNext: { [weak self] error in
                switch error.field ?? "" {
                case "loginId":
                    self?.loginIdInputView.showError(error.message ?? "")
                case "email":
                    self?.emailInputView.showError(error.message ?? "")
                case "password":
                    self?.passwordInputView.showError(error.message ?? "")
                case "passwordCheck":
                    self?.passwordCheckInputView.showError(error.message ?? "")
                case "username":
                    self?.nicknameInputView.showError(error.message ?? "")
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }
}

extension SignUpViewController: KeyboardManagerDelegate {
    func keyboardManager(_ keyboardManager: KeyboardManager, keyboardWillChangeFrame endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions) {
        guard let endFrame = endFrame else { return }

        if endFrame.origin.y >= SCREEN_H {
            scrollView.contentInset = .zero
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.size.height, right: 0)
        }

        UIView.animate(withDuration: duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

extension SignUpViewController: DynamicInputViewDelegate {
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
            textField.resignFirstResponder()
        }
    }
}
