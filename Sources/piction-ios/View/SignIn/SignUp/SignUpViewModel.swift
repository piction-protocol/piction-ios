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
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
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
        let userInfo: Driver<UserModel>
        let signUpBtnEnable: Driver<Void>
        let openSignUpComplete: Driver<Void>
        let activityIndicator: Driver<Bool>
        let errorMsg: Driver<ErrorModel>
    }

    func build(input: Input) -> Output {
        let updater = self.updater

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let userInfoAction = viewWillAppear
            .map { UsersAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let signUpInfo = Driver.combineLatest(input.loginIdTextFieldDidInput, input.emailTextFieldDidInput, input.passwordTextFieldDidInput, input.passwordCheckTextFieldDidInput, input.nicknameTextFieldDidInput) { (loginId: $0, email: $1, password: $2, passwordCheck: $3, username: $4) }

        let signUpButtonAction = input.signUpBtnDidTap
            .withLatestFrom(signUpInfo)
            .map { UsersAPI.signup(loginId: $0.loginId, email: $0.email, username: $0.username, password: $0.password, passwordCheck: $0.passwordCheck) }
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
            .map { SessionsAPI.create(loginId: $0.loginId, password: $0.password, rememberme: true) }
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

        let activityIndicator = signUpSuccessAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            signUpBtnEnable: input.agreeBtnDidTap,
            openSignUpComplete: sessionCreateSuccess,
            activityIndicator: activityIndicator,
            errorMsg: errorMsg
        )
    }
}
