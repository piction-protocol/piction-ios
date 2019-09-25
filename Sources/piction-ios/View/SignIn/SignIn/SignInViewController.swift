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

final class SignInViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var findPasswordButton: UIButton!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

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

    private func openSignUpViewController() {
        let vc = SignUpViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openRegisterPincode() {
        let vc = RegisterPincodeViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
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

extension SignInViewController: ViewModelBindable {

    typealias ViewModel = SignInViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = SignInViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
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
                self?.navigationController?.navigationBar.prefersLargeTitles = false
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
            .dismissViewController
            .drive(onNext: { [weak self] complete in
                self?.dismiss(animated: true, completion: { [weak self] in
                    if complete {
                        if UserDefaults.standard.string(forKey: "pincode") == nil {
                            self?.openRegisterPincode()
                        }
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

extension SignInViewController: KeyboardManagerDelegate {
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
