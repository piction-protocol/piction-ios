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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension ChangePasswordViewModel {
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
}

// MARK: - ViewModel Build
extension ChangePasswordViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, keyboardManager) = (self.firebaseManager, self.keyboardManager)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("마이페이지_비밀번호변경")
                // 키보드가 올라오는지 모니터링
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                // 키보드 모니터링 중단
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

        let errorMsg = changePasswordError

        // 로딩 뷰
        let activityIndicator = saveButtonAction.isExecuting

        let dismissWithCancel = input.cancelBtnDidTap

        let dismissViewController = Driver.merge(dismissWithCancel, changePasswordSuccess)
            .map { _ in Void() }

        // 키보드로 인한 frame 변경 시
        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame
            .asDriver(onErrorDriveWith: .empty())

        // 토스트 메시지
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

