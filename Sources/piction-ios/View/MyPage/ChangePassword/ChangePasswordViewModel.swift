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

final class ChangePasswordViewModel: ViewModel {

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
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
        let activityIndicator: Driver<Bool>
        let passwordVisible: Driver<Void>
        let newPasswordVisible: Driver<Void>
        let passwordCheckVisible: Driver<Void>
        let enableSaveButton: Driver<Void>
        let dismissViewController: Driver<Void>
        let errorMsg: Driver<ErrorModel>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let changePasswordInfo = Driver.combineLatest(input.passwordTextFieldDidInput, input.newPasswordTextFieldDidInput, input.passwordCheckTextFieldDidInput) { (password: $0, newPassword: $1, passwordCheck: $2) }

        let enableSaveButton = changePasswordInfo
            .filter { $0 != "" && $1 != "" && $2 != "" }
            .map { _ in Void() }

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(changePasswordInfo)
            .map { UsersAPI.updatePassword(password: $0.password, newPassword: $0.newPassword, passwordCheck: $0.passwordCheck) }
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

        let showToast = saveButtonAction.error
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

        return Output(
            viewWillAppear: input.viewWillAppear,
            activityIndicator: activityIndicator,
            passwordVisible: input.passwordVisibleBtnDidTap,
            newPasswordVisible: input.newPasswordVisibleBtnDidTap,
            passwordCheckVisible: input.passwordCheckVisibleBtnDidTap,
            enableSaveButton: enableSaveButton,
            dismissViewController: dismissViewController,
            errorMsg: errorMsg,
            showToast: showToast
        )
    }
}

