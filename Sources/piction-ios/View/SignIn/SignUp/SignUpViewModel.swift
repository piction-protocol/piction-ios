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
        let termsBtnDidTap: Driver<Void>
        let privacyBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let signUpBtnEnable: Driver<Void>
        let openSignUpComplete: Driver<Void>
        let openTermsView: Driver<Void>
        let openPrivacyView: Driver<Void>
        let activityIndicator: Driver<Bool>
        let errorMsg: Driver<ErrorModel>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear

        let signUpInfo = Driver.combineLatest(input.loginIdTextFieldDidInput, input.emailTextFieldDidInput, input.passwordTextFieldDidInput, input.passwordCheckTextFieldDidInput, input.nicknameTextFieldDidInput) { (loginId: $0, email: $1, password: $2, passwordCheck: $3, username: $4) }

        let signUpButtonAction = input.signUpBtnDidTap
            .withLatestFrom(signUpInfo)
            .flatMap { signUpInfo -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.signup(loginId: signUpInfo.loginId, email: signUpInfo.email, username: signUpInfo.username, password: signUpInfo.password, passwordCheck: signUpInfo.passwordCheck))
                return Action.makeDriver(response)
            }

        let signUpError = signUpButtonAction.error
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

        let clearErrorMsg = Driver.merge(input.loginIdTextFieldDidInput, input.emailTextFieldDidInput, input.passwordTextFieldDidInput, input.passwordCheckTextFieldDidInput, input.nicknameTextFieldDidInput)
            .flatMap { _ in Driver.just(ErrorModel.from([:])!) }

        let errorMsg = Driver.merge(signUpError, clearErrorMsg)

        let signUpSuccessAction = signUpButtonAction.elements
            .withLatestFrom(signUpInfo)
            .flatMap { signUpInfo -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SessionsAPI.create(loginId: signUpInfo.loginId, password: signUpInfo.password, rememberme: true))
                return Action.makeDriver(response)
            }

        let sessionCreateSuccess = signUpSuccessAction.elements
            .flatMap { [weak self] response -> Driver<Void> in
                guard let accessToken = try? response.map(to: AuthenticationViewResponse.self) else {
                    return Driver.empty()
                }
                self?.updater.refreshSession.onNext(())
                print(accessToken)
                return Driver.just(())
            }

        let showActivityIndicator = input.signUpBtnDidTap
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = Driver.merge(signUpSuccessAction.error, signUpButtonAction.error)
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        let openTermsView = input.termsBtnDidTap
        let openPrivacyView = input.privacyBtnDidTap

        return Output(
            viewWillAppear: viewWillAppear,
            signUpBtnEnable: input.agreeBtnDidTap,
            openSignUpComplete: sessionCreateSuccess,
            openTermsView: openTermsView,
            openPrivacyView: openPrivacyView,
            activityIndicator: activityIndicator,
            errorMsg: errorMsg
        )
    }
}
