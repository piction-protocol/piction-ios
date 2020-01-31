//
//  ChangePasswordViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ChangePasswordViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        KeyboardManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let keyboardManager: KeyboardManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager, keyboardManager) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let passwordTextFieldDidInput: Driver<String>
        let newPasswordTextFieldDidInput: Driver<String>
        let passwordCheckTextFieldDidInput: Driver<String>
        let passwordVisibleBtnDidTap: Driver<Void>
        let newPasswordVisibleBtnDidTap: Driver<Void>
        let passwordCheckVisibleBtnDidTap: Driver<Void>
        let saveBtnDidTap: Driver<Void>
        let cancelBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let activityIndicator: Driver<Bool>
        let passwordVisible: Driver<Void>
        let newPasswordVisible: Driver<Void>
        let passwordCheckVisible: Driver<Void>
        let enableSaveButton: Driver<Void>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let dismissViewController: Driver<Void>
        let errorMsg: Driver<ErrorModel>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, keyboardManager) = (self.firebaseManager, self.keyboardManager)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("마이페이지_비밀번호변경")
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                keyboardManager.stopMonitoring()
            })

        let changePasswordInfo = Driver.combineLatest(input.passwordTextFieldDidInput, input.newPasswordTextFieldDidInput, input.passwordCheckTextFieldDidInput) { (password: $0, newPassword: $1, passwordCheck: $2) }

        let enableSaveButton = changePasswordInfo
            .filter { $0 != "" && $1 != "" && $2 != "" }
            .map { _ in Void() }

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(changePasswordInfo)
            .map { UserAPI.updatePassword(password: $0.password, newPassword: $0.newPassword, passwordCheck: $0.passwordCheck) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let changePasswordError = saveButtonAction.error
            .flatMap { response -> Driver<ErrorModel> in
                let errorMsg = response as? ErrorType
                switch errorMsg {
                case .badRequest(let error):
                    return Driver.just(error)
                default:
                    return Driver.empty()
                }
            }

        let changePasswordSuccess = saveButtonAction.elements
            .map { _ in Void() }

        let toastMessage = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field != nil:
                    return Driver.empty()
                default:
                    return Driver.just(errorType?.message ?? "")
                }
            }

        let errorMsg = changePasswordError

        let activityIndicator = saveButtonAction.isExecuting

        let dismissWithCancel = input.cancelBtnDidTap

        let dismissViewController = Driver.merge(dismissWithCancel, changePasswordSuccess)
            .map { _ in Void() }

        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame.asDriver(onErrorDriveWith: .empty())

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            activityIndicator: activityIndicator,
            passwordVisible: input.passwordVisibleBtnDidTap,
            newPasswordVisible: input.newPasswordVisibleBtnDidTap,
            passwordCheckVisible: input.passwordCheckVisibleBtnDidTap,
            enableSaveButton: enableSaveButton,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            dismissViewController: dismissViewController,
            errorMsg: errorMsg,
            toastMessage: toastMessage
        )
    }
}

