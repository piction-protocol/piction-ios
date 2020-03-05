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

// MARK: - UIViewController
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

    // password textfield에서 return key 누르면 login 되도록 함
    private let keyboardReturnSignIn = PublishSubject<Void>()

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SignInViewController: ViewModelBindable {
    typealias ViewModel = SignInViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = SignInViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            signInBtnDidTap: Driver.merge(signInButton.rx.tap.asDriver(), keyboardReturnSignIn.asDriver(onErrorDriveWith: .empty())), // 로그인 버튼이나 키보드의 return 버튼을 눌렀을 때
            signUpBtnDidTap: signUpButton.rx.tap.asDriver(), // 회원가입 버튼을 눌렀을 때
            loginIdTextFieldDidInput: loginIdInputView.inputTextField.rx.text.orEmpty.asDriver(), // id textfield를 입력했을 때
            passwordTextFieldDidInput: passwordInputView.inputTextField.rx.text.orEmpty.asDriver(), // password textfield를 입력했을 때
            findPasswordBtnDidTap: findPasswordButton.rx.tap.asDriver(), // 비밀번호 찾기 버튼을 눌렀을 때
            closeBtnDidTap: closeButton.rx.tap.asDriver() // 닫기 버튼을 눌렀을 때
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

        // 회원가입 화면으로 push
        output
            .openSignUpViewController
            .map { .signUp }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // 비밀번호 찾기는 safari로 open
        output
            .openFindPassword
            .drive(onNext: { [weak self] in
                let stagingPath = AppInfo.isStaging ? "staging." : ""
                self?.openSafariViewController(url: "https://\(stagingPath)piction.network/forgot_password")
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

        // 로그인 후 pincode 등록이 안되있으면 화면을 닫은 후 pincode 등록 화면 출력
        output
            .dismissViewController
            .drive(onNext: { [weak self] pincodeEmpty in
                self?.dismiss(animated: true) {
                    if pincodeEmpty {
                        self?.openView(type: .registerPincode, openType: .present)
                    }
                }
            })
            .disposed(by: disposeBag)

        // 에러 메시지를 각 field 밑에 출력
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
extension SignInViewController {
    // 화면 tap 시 키보드 숨기기
    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

// MARK: - DynamicInputViewDelegate
extension SignInViewController: DynamicInputViewDelegate {
    // 키보드의 return 키 눌렀을 때 다음 textField로 이동
    func returnKeyAction(_ textField: UITextField) {
        if textField === loginIdInputView.inputTextField {
            passwordInputView.inputTextField.becomeFirstResponder()
        } else {
            passwordInputView.inputTextField.resignFirstResponder()
            // 마지막 textField는 편하게 바로 로그인 할 수 있도록 함
            keyboardReturnSignIn.onNext(())
        }
    }
}
