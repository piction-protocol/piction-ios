//
//  ChangePasswordViewController.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class ChangePasswordViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var newPasswordTextField: UITextField!
    @IBOutlet weak var passwordCheckTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIBarButtonItem!

    @IBOutlet weak var passwordTitleLabel: UILabel!
    @IBOutlet weak var passwordUnderlineView: UIView!
    @IBOutlet weak var passwordErrorLabel: UILabel!

    @IBOutlet weak var newPasswordTitleLabel: UILabel!
    @IBOutlet weak var newPasswordUnderlineView: UIView!
    @IBOutlet weak var newPasswordErrorLabel: UILabel!


    @IBOutlet weak var passwordCheckTitleLabel: UILabel!
    @IBOutlet weak var passwordCheckUnderlineView: UIView!
    @IBOutlet weak var passwordCheckErrorLabel: UILabel!

    @IBOutlet weak var passwordVisibleButton: UIButton!
    @IBOutlet weak var newPasswordVisibleButton: UIButton!
    @IBOutlet weak var passwordCheckVisibleButton: UIButton!

    private let keyboardReturnSave = PublishSubject<Void>()

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension ChangePasswordViewController: ViewModelBindable {

    typealias ViewModel = ChangePasswordViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = ChangePasswordViewModel.Input(
            passwordTextFieldDidInput: passwordTextField.rx.text.orEmpty.asDriver(),
            newPasswordTextFieldDidInput: newPasswordTextField.rx.text.orEmpty.asDriver(),
            passwordCheckTextFieldDidInput: passwordCheckTextField.rx.text.orEmpty.asDriver(),
            passwordVisibleBtnDidTap: passwordVisibleButton.rx.tap.asDriver(),
            newPasswordVisibleBtnDidTap: newPasswordVisibleButton.rx.tap.asDriver(),
            passwordCheckVisibleBtnDidTap: passwordCheckVisibleButton.rx.tap.asDriver(),
            saveBtnDidTap: saveButton.rx.tap.asDriver(),
            cancelBtnDidTap: cancelButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

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
            .passwordVisible
            .drive(onNext: { [weak self] in
                if self?.passwordTextField.isSecureTextEntry ?? true {
                    self?.passwordTextField.isSecureTextEntry = false
                    self?.passwordVisibleButton.setImage(#imageLiteral(resourceName: "icVisibilityOff") ,for: .normal)
                } else {
                    self?.passwordTextField.isSecureTextEntry = true
                    self?.passwordVisibleButton.setImage(#imageLiteral(resourceName: "icVisibilityOn") ,for: .normal)
                }
            })
            .disposed(by: disposeBag)

        output
            .newPasswordVisible
            .drive(onNext: { [weak self] in
                if self?.newPasswordTextField.isSecureTextEntry ?? true {
                    self?.newPasswordTextField.isSecureTextEntry = false
                    self?.newPasswordVisibleButton.setImage(#imageLiteral(resourceName: "icVisibilityOff") ,for: .normal)
                } else {
                    self?.newPasswordTextField.isSecureTextEntry = true
                    self?.newPasswordVisibleButton.setImage(#imageLiteral(resourceName: "icVisibilityOn") ,for: .normal)
                }
            })
            .disposed(by: disposeBag)

        output
            .passwordCheckVisible
            .drive(onNext: { [weak self] in
                if self?.passwordCheckTextField.isSecureTextEntry ?? true {
                    self?.passwordCheckTextField.isSecureTextEntry = false
                    self?.passwordCheckVisibleButton.setImage(#imageLiteral(resourceName: "icVisibilityOff") ,for: .normal)
                } else {
                    self?.passwordCheckTextField.isSecureTextEntry = true
                    self?.passwordCheckVisibleButton.setImage(#imageLiteral(resourceName: "icVisibilityOn") ,for: .normal)
                }
            })
            .disposed(by: disposeBag)

        output
            .enableSaveButton
            .drive(onNext: { [weak self] in
                self?.saveButton.setTitleColor(.white, for: .normal)
                self?.saveButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                self?.saveButton.isEnabled = true
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .errorMsg
            .drive(onNext: { [weak self] error in
                self?.passwordTextField.resignFirstResponder()
                self?.newPasswordTextField.resignFirstResponder()
                self?.passwordCheckTextField.resignFirstResponder()
                switch error.field ?? "" {
                case "password":
                    self?.passwordTextField.textColor = UIColor(r: 213, g: 19, b: 21)
                    self?.passwordErrorLabel.text = error.message ?? ""
                    self?.passwordUnderlineView.backgroundColor = UIColor(r: 213, g: 19, b: 21)
                    self?.passwordErrorLabel.isHidden = false
                case "newPassword":
                    self?.newPasswordTextField.textColor = UIColor(r: 213, g: 19, b: 21)
                    self?.newPasswordErrorLabel.text = error.message ?? ""
                    self?.newPasswordUnderlineView.backgroundColor = UIColor(r: 213, g: 19, b: 21)
                    self?.newPasswordErrorLabel.isHidden = false
                case "passwordCheck":
                    self?.passwordCheckTextField.textColor = UIColor(r: 213, g: 19, b: 21)
                    self?.passwordCheckErrorLabel.text = error.message ?? ""
                    self?.passwordCheckUnderlineView.backgroundColor = UIColor(r: 213, g: 19, b: 21)
                    self?.passwordCheckErrorLabel.isHidden = false
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

//        output
//            .showToast
//            .drive(onNext: { message in
//                Toast.showToast(message)
//            })
//            .disposed(by: disposeBag)
    }
}

extension ChangePasswordViewController: KeyboardManagerDelegate {
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

extension ChangePasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === passwordTextField {
            newPasswordTextField.becomeFirstResponder()
        } else if textField == newPasswordTextField {
            passwordCheckTextField.becomeFirstResponder()
        } else if textField == passwordCheckTextField {
            textField.resignFirstResponder()
            self.keyboardReturnSave.onNext(())
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === passwordTextField {
            passwordUnderlineView.backgroundColor = UIColor(r: 26, g: 146, b: 255)
            passwordTextField.textColor = UIColor(r: 51, g: 51, b: 51)
            passwordErrorLabel.isHidden = true
        } else if textField == newPasswordTextField {
            newPasswordUnderlineView.backgroundColor = UIColor(r: 26, g: 146, b: 255)
            newPasswordTextField.textColor = UIColor(r: 51, g: 51, b: 51)
            newPasswordErrorLabel.isHidden = true
        } else if textField == passwordCheckTextField {
            passwordCheckUnderlineView.backgroundColor = UIColor(r: 26, g: 146, b: 255)
            passwordCheckTextField.textColor = UIColor(r: 51, g: 51, b: 51)
            passwordCheckErrorLabel.isHidden = true
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === passwordTextField {
            passwordUnderlineView.backgroundColor = UIColor(r: 51, g: 51, b: 51)
        } else if textField == newPasswordTextField {
            newPasswordUnderlineView.backgroundColor = UIColor(r: 51, g: 51, b: 51)
        } else if textField == passwordCheckTextField {
            passwordCheckUnderlineView.backgroundColor = UIColor(r: 51, g: 51, b: 51)
        }
    }
}
