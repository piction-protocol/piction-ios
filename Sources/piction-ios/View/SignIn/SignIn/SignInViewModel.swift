//
//  SignInViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SignInViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let signInBtnDidTap: Driver<Void>
        let signUpBtnDidTap: Driver<Void>
        let loginIdTextFieldDidInput: Driver<String>
        let passwordTextFieldDidInput: Driver<String>
        let findPasswordBtnDidTap: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let userInfo: Driver<UserModel>
        let activityIndicator: Driver<Bool>
        let openSignUpViewController: Driver<Void>
        let openFindPassword: Driver<Void>
        let dismissViewController: Driver<Bool>
        let errorMsg: Driver<ErrorModel>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let userInfoAction = viewWillAppear
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
            }

        let signInInfo = Driver.combineLatest(input.loginIdTextFieldDidInput, input.passwordTextFieldDidInput) { (loginId: $0, password: $1) }

        let signInButtonAction = input.signInBtnDidTap
            .withLatestFrom(signInInfo)
            .flatMap { signInInfo -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SessionsAPI.create(loginId: signInInfo.loginId, password: signInInfo.password, rememberme: true))
                return Action.makeDriver(response)
            }

        let signInError = signInButtonAction.error
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

        let showToast = signInButtonAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }

                switch errorMsg {
                case .badRequest(let error):
                    if error.field == nil {
                        return Driver.just(errorMsg.message)
                    } else {
                        return Driver.empty()
                    }
                default:
                    return Driver.just(errorMsg.message)
                }
            }

        let signInSuccess = signInButtonAction.elements
            .flatMap { [weak self] response -> Driver<Bool> in
                guard let accessToken = try? response.map(to: AuthenticationViewResponse.self) else {
                    return Driver.empty()
                }
                self?.updater.refreshSession.onNext(())
                print(accessToken)
                return Driver.just(true)
            }

        let openSignUpViewController = input.signUpBtnDidTap

        let openFindPassword = input.findPasswordBtnDidTap

        let showActivityIndicator = input.signInBtnDidTap
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = signInButtonAction.error
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)
            .flatMap { status in Driver.just(status) }

        let closeAction = input.closeBtnDidTap
            .flatMap { _ -> Driver<Bool> in
                return Driver.just(false)
            }

        let dismissViewController = Driver.merge(signInSuccess, closeAction)

        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            activityIndicator: activityIndicator,
            openSignUpViewController: openSignUpViewController,
            openFindPassword: openFindPassword,
            dismissViewController: dismissViewController,
            errorMsg: signInError,
            showToast: showToast
        )
    }
}
