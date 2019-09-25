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
import RxPictionSDK

final class ChangePasswordViewModel: ViewModel {

    init() {}

    struct Input {
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
        let activityIndicator: Driver<Bool>
        let passwordVisible: Driver<Void>
        let newPasswordVisible: Driver<Void>
        let passwordCheckVisible: Driver<Void>
        let enableSaveButton: Driver<Void>
        let dismissViewController: Driver<Void>
        let errorMsg: Driver<ErrorModel>
    }

    func build(input: Input) -> Output {
        let changePasswordInfo = Driver.combineLatest(input.passwordTextFieldDidInput, input.newPasswordTextFieldDidInput, input.passwordCheckTextFieldDidInput) { (password: $0, newPassword: $1, passwordCheck: $2) }

        let enableSaveButton = changePasswordInfo
            .filter { $0 != "" && $1 != "" && $2 != "" }
            .flatMap { _ in Driver.just(()) }

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(changePasswordInfo)
            .flatMap { changePasswordInfo -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.updatePassword(password: changePasswordInfo.password, newPassword: changePasswordInfo.newPassword, passwordCheck: changePasswordInfo.passwordCheck))
                return Action.makeDriver(response)
            }

        let changePasswordError = saveButtonAction.error
            .flatMap { response -> Driver<ErrorModel> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }

                switch errorMsg {
                case .badRequest(let error):
                    return Driver.just(error)
                default:
                    return Driver.empty()
                }
            }

        let changePasswordSuccess = saveButtonAction.elements
            .flatMap { response -> Driver<Void> in
                guard let accessToken = try? response.map(to: AuthenticationViewResponse.self) else {
                    return Driver.empty()
                }
                print(accessToken)
                return Driver.just(())
            }

        let errorMsg = changePasswordError

        let showActivityIndicator = input.saveBtnDidTap
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = saveButtonAction.error
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)
            .flatMap { status in Driver.just(status) }

        let dismissWithCancel = input.cancelBtnDidTap

        let dismissViewController = Driver.merge(dismissWithCancel, changePasswordSuccess)
            .flatMap { _ in Driver.just(()) }

        return Output(
            activityIndicator: activityIndicator,
            passwordVisible: input.passwordVisibleBtnDidTap,
            newPasswordVisible: input.newPasswordVisibleBtnDidTap,
            passwordCheckVisible: input.passwordCheckVisibleBtnDidTap,
            enableSaveButton: enableSaveButton,
            dismissViewController: dismissViewController,
            errorMsg: errorMsg
        )
    }
}

