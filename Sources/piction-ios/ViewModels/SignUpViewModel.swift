//
//  SignUpViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SignUpViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        KeyboardManager
    )

    private let updater: UpdaterProtocol
    private let keyboardManager: KeyboardManager

    init(dependency: Dependency) {
        (updater, keyboardManager) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let signUpBtnDidTap: Driver<Void>
        let loginIdTextFieldDidInput: Driver<String>
        let emailTextFieldDidInput: Driver<String>
        let passwordTextFieldDidInput: Driver<String>
        let passwordCheckTextFieldDidInput: Driver<String>
        let nicknameTextFieldDidInput: Driver<String>
        let agreeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let userInfo: Driver<UserModel>
        let signUpBtnEnable: Driver<Void>
        let openSignUpComplete: Driver<Void>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let activityIndicator: Driver<Bool>
        let errorMsg: Driver<ErrorModel>
    }

    func build(input: Input) -> Output {
        let (updater, keyboardManager) = (self.updater, self.keyboardManager)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                keyboardManager.stopMonitoring()
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let userInfoAction = initialLoad
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let signUpInfo = Driver.combineLatest(input.loginIdTextFieldDidInput, input.emailTextFieldDidInput, input.passwordTextFieldDidInput, input.passwordCheckTextFieldDidInput, input.nicknameTextFieldDidInput) { (loginId: $0, email: $1, password: $2, passwordCheck: $3, username: $4) }

        let signUpButtonAction = input.signUpBtnDidTap
            .withLatestFrom(signUpInfo)
            .map { UserAPI.signup(loginId: $0.loginId, email: $0.email, username: $0.username, password: $0.password, passwordCheck: $0.passwordCheck) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let signUpError = signUpButtonAction.error
            .flatMap { response -> Driver<ErrorModel> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error):
                    return Driver.just(error)
                default:
                    return Driver.empty()
                }
            }

        let clearErrorMsg = Driver.merge(input.loginIdTextFieldDidInput, input.emailTextFieldDidInput, input.passwordTextFieldDidInput, input.passwordCheckTextFieldDidInput, input.nicknameTextFieldDidInput)
            .map { _ in ErrorModel.from([:])! }

        let errorMsg = Driver.merge(signUpError, clearErrorMsg)

        let signUpSuccessAction = signUpButtonAction.elements
            .withLatestFrom(signUpInfo)
            .map { SessionAPI.create(loginId: $0.loginId, password: $0.password, rememberme: true) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let sessionCreateSuccess = signUpSuccessAction.elements
            .map { try? $0.map(to: AuthenticationViewResponse.self) }
            .map { $0?.accessToken ?? "" }
            .do(onNext: { token in
                KeychainManager.set(key: "AccessToken", value: token)
                PictionManager.setToken(token)
                updater.refreshSession.onNext(())
            })
            .map { _ in Void() }

        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame.asDriver(onErrorDriveWith: .empty())

        let activityIndicator = signUpSuccessAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            userInfo: userInfoSuccess,
            signUpBtnEnable: input.agreeBtnDidTap,
            openSignUpComplete: sessionCreateSuccess,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            activityIndicator: activityIndicator,
            errorMsg: errorMsg
        )
    }
}
