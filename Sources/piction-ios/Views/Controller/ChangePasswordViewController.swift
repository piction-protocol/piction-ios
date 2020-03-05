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

// MARK: - UIViewController
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

    // 키보드 return을 통해 저장할 때 Observable
    private let keyboardReturnSave = PublishSubject<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // present 타입의 경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ChangePasswordViewController: ViewModelBindable {
    typealias ViewModel = ChangePasswordViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = ChangePasswordViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            passwordTextFieldDidInput: passwordTextField.rx.text.orEmpty.asDriver(), // 현재 password textField 입력 시
            newPasswordTextFieldDidInput: newPasswordTextField.rx.text.orEmpty.asDriver(), // 새로운 password textField 입력 시
            passwordCheckTextFieldDidInput: passwordCheckTextField.rx.text.orEmpty.asDriver(), // password textField 확인 입력 시
            passwordVisibleBtnDidTap: passwordVisibleButton.rx.tap.asDriver(), // 현재 password의 비밀번호 보기 버튼 눌렀을 때
            newPasswordVisibleBtnDidTap: newPasswordVisibleButton.rx.tap.asDriver(), // 새로운 password의 비밀번호 보기 버튼 눌렀을 때
            passwordCheckVisibleBtnDidTap: passwordCheckVisibleButton.rx.tap.asDriver(), // password 확인의 비밀번호 보기 버튼 눌렀을 때
            saveBtnDidTap: saveButton.rx.tap.asDriver(), // 저장 버튼 눌렀을 때
            cancelBtnDidTap: cancelButton.rx.tap.asDriver() // 취소 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에
        output
            .viewWillAppear
            .drive()
            .disposed(by: disposeBag)

        // 화면이 사라지기전에 viewModel에서 keyboard를 숨기고 disposed하기 위함
        output
            .viewWillDisappear
            .drive()
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // password TextField의 보기/숨기기 버튼 눌렀을 때
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

        // 새로운 패스워드 TextField의 보기/숨기기 버튼 눌렀을 때
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

        // 패스워드 확인 TextField의 보기/숨기기 버튼 눌렀을 때
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

        // 저장 버튼 활성/비활성화
        output
            .enableSaveButton
            .drive(onNext: { [weak self] in
                self?.saveButton.setTitleColor(.white, for: .normal)
                self?.saveButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                self?.saveButton.isEnabled = true
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

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        // 에러 메시지를 각 field 밑에 출력
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

        // 토스트 메시지 출력 (키보드에 가리기 때문에 키보드 숨긴 후 출력)
        output
            .toastMessage
            .do(onNext: { [weak self] message in
                self?.view.endEditing(true)
            })
            .showToast()
            .disposed(by: disposeBag)
    }
}

// MARK: - IBAction
extension ChangePasswordViewController {
    // 화면 tap 시 키보드 숨기기
    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate
extension ChangePasswordViewController: UITextFieldDelegate {
    // 키보드의 return 키 눌렀을 때 다음 textField로 이동
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === passwordTextField {
            newPasswordTextField.becomeFirstResponder()
        } else if textField == newPasswordTextField {
            passwordCheckTextField.becomeFirstResponder()
        } else if textField == passwordCheckTextField {
            textField.resignFirstResponder()
            // 마지막 textField에서는 바로 저장할 수 있도록 함
            self.keyboardReturnSave.onNext(())
        }
        return true
    }

    // textField에 입력을 시작할 때
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

    // textField에 입력이 끝났을 때
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
