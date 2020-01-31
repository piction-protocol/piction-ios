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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension ChangePasswordViewController: ViewModelBindable {

    typealias ViewModel = ChangePasswordViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = ChangePasswordViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
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
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { _ in
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
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
                    self?.passwordTextField.textColor = .pictionRed
                    self?.passwordErrorLabel.text = error.message ?? ""
                    self?.passwordUnderlineView.backgroundColor = .pictionRed
                    self?.passwordErrorLabel.isHidden = false
                case "newPassword":
                    self?.newPasswordTextField.textColor = .pictionRed
                    self?.newPasswordErrorLabel.text = error.message ?? ""
                    self?.newPasswordUnderlineView.backgroundColor = .pictionRed
                    self?.newPasswordErrorLabel.isHidden = false
                case "passwordCheck":
                    self?.passwordCheckTextField.textColor = .pictionRed
                    self?.passwordCheckErrorLabel.text = error.message ?? ""
                    self?.passwordCheckUnderlineView.backgroundColor = .pictionRed
                    self?.passwordCheckErrorLabel.isHidden = false
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { [weak self] message in
                self?.passwordTextField.resignFirstResponder()
                self?.newPasswordTextField.resignFirstResponder()
                self?.passwordCheckTextField.resignFirstResponder()
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
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
            passwordUnderlineView.backgroundColor = .pictionBlue
            passwordTextField.textColor = .pictionDarkGrayDM
            passwordErrorLabel.isHidden = true
        } else if textField == newPasswordTextField {
            newPasswordUnderlineView.backgroundColor = .pictionBlue
            newPasswordTextField.textColor = .pictionDarkGrayDM
            newPasswordErrorLabel.isHidden = true
        } else if textField == passwordCheckTextField {
            passwordCheckUnderlineView.backgroundColor = .pictionBlue
            passwordCheckTextField.textColor = .pictionDarkGrayDM
            passwordCheckErrorLabel.isHidden = true
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === passwordTextField {
            passwordUnderlineView.backgroundColor = .pictionDarkGrayDM
        } else if textField == newPasswordTextField {
            newPasswordUnderlineView.backgroundColor = .pictionDarkGrayDM
        } else if textField == passwordCheckTextField {
            passwordCheckUnderlineView.backgroundColor = .pictionDarkGrayDM
        }
    }
}
