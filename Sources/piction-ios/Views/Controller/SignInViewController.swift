//
//  SignInViewController.swift
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

final class SignInViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var findPasswordButton: UIButton!

    @IBOutlet weak var loginIdInputView: DynamicInputView! {
        didSet {
            loginIdInputView.delegate = self
        }
    }
    @IBOutlet weak var passwordInputView: DynamicInputView! {
        didSet {
            passwordInputView.delegate = self
        }
    }

    private let keyboardReturnSignIn = PublishSubject<Void>()

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension SignInViewController: ViewModelBindable {

    typealias ViewModel = SignInViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = SignInViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            signInBtnDidTap: Driver.merge(signInButton.rx.tap.asDriver(), keyboardReturnSignIn.asDriver(onErrorDriveWith: .empty())),
            signUpBtnDidTap: signUpButton.rx.tap.asDriver(),
            loginIdTextFieldDidInput: loginIdInputView.inputTextField.rx.text.orEmpty.asDriver(),
            passwordTextFieldDidInput: passwordInputView.inputTextField.rx.text.orEmpty.asDriver(),
            findPasswordBtnDidTap: findPasswordButton.rx.tap.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { _ in
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                if userInfo.loginId != "" {
                    self?.dismiss(animated: true, completion: {
                        Toast.showToast(LocalizationKey.msg_already_sign_in.localized())
                    })
                }
            })
            .disposed(by: disposeBag)

        output
            .openSignUpViewController
            .drive(onNext: { [weak self] in
                self?.openSignUpViewController()
            })
            .disposed(by: disposeBag)

        output
            .openFindPassword
            .drive(onNext: { _ in
                let stagingPath = AppInfo.isStaging ? "staging." : ""

                if let url = URL(string: "https://\(stagingPath)piction.network/forgot_password") {
                    let safariViewController = SFSafariViewController(url: url)
                    self.present(safariViewController, animated: true, completion: nil)
                }
            })
            .disposed(by: disposeBag)

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

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] keychainEmpty in
                self?.dismiss(animated: true, completion: { [weak self] in
                    if keychainEmpty {
                        self?.openRegisterPincodeViewController()
                    }
                })
            })
            .disposed(by: disposeBag)

        output
            .errorMsg
            .drive(onNext: { [weak self] error in
                switch error.field ?? "" {
                case "loginId":
                    self?.loginIdInputView.showError(error.message ?? "")
                case "password":
                    self?.passwordInputView.showError(error.message ?? "")
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { [weak self] message in
                self?.loginIdInputView.inputTextField.resignFirstResponder()
                self?.passwordInputView.inputTextField.resignFirstResponder()
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
    }
}

extension SignInViewController: DynamicInputViewDelegate {
    func returnKeyAction(_ textField: UITextField) {
        if textField === loginIdInputView.inputTextField {
            passwordInputView.inputTextField.becomeFirstResponder()
        } else {
            passwordInputView.inputTextField.resignFirstResponder()
            self.keyboardReturnSignIn.onNext(())
        }
    }
}
