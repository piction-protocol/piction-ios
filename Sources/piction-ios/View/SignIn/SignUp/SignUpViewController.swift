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

    @IBOutlet weak var checkboxImageView: UIImageView!
    @IBOutlet weak var agreeButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var termsButton: UIButton!
    @IBOutlet weak var privacyButton: UIButton!

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

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    private func openSignUpComplete() {
        let vc = SignUpCompleteViewController.make()
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
            agreeBtnDidTap: agreeButton.rx.tap.asDriver(),
            termsBtnDidTap: termsButton.rx.tap.asDriver(),
            privacyBtnDidTap: privacyButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.navigationBar.prefersLargeTitles = false
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
                self?.openSignUpComplete()
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { [weak self] status in
                if status {
                    self?.view.makeToastActivity(.center)
                } else {
                    self?.view.hideToastActivity()
                }
            })
            .disposed(by: disposeBag)

        output
            .openTermsView
            .drive(onNext: { [weak self] in
                guard let url = URL(string: "https://piction.network/terms") else { return }
                let safariViewController = SFSafariViewController(url: url)
                self?.present(safariViewController, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        output
            .openPrivacyView
            .drive(onNext: { [weak self] in
                guard let url = URL(string: "https://piction.network/privacy") else { return }
                let safariViewController = SFSafariViewController(url: url)
                self?.present(safariViewController, animated: true, completion: nil)
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
            bottomConstraint.constant = 0
        } else {
            bottomConstraint.constant = endFrame.size.height
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
