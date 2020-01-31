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
        FirebaseManagerProtocol,
        UpdaterProtocol,
        KeyboardManagerProtocol,
        KeychainManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let keyboardManager: KeyboardManagerProtocol
    private let keychainManager: KeychainManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager, updater, keyboardManager, keychainManager) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let signInBtnDidTap: Driver<Void>
        let signUpBtnDidTap: Driver<Void>
        let loginIdTextFieldDidInput: Driver<String>
        let passwordTextFieldDidInput: Driver<String>
        let findPasswordBtnDidTap: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let userInfo: Driver<UserModel>
        let activityIndicator: Driver<Bool>
        let openSignUpViewController: Driver<Void>
        let openFindPassword: Driver<Void>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let dismissViewController: Driver<Bool>
        let errorMsg: Driver<ErrorModel>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, keyboardManager, keychainManager) = (self.firebaseManager, self.updater, self.keyboardManager, self.keychainManager)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("로그인")
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

        let signInInfo = Driver.combineLatest(input.loginIdTextFieldDidInput, input.passwordTextFieldDidInput) { (loginId: $0, password: $1) }

        let signInButtonAction = input.signInBtnDidTap
            .withLatestFrom(signInInfo)
            .map { SessionAPI.create(loginId: $0.loginId, password: $0.password, rememberme: true) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let signInError = signInButtonAction.error
            .flatMap { response -> Driver<ErrorModel> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error):
                    return Driver.just(error)
                default:
                    return Driver.empty()
                }
            }

        let toastMessage = signInButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field != nil:
                    return Driver.empty()
                default:
                    return Driver.just(errorType?.message ?? "")
                }
            }

        let signInSuccess = signInButtonAction.elements
            .map { try? $0.map(to: AuthenticationModel.self) }
            .map { $0?.accessToken ?? "" }
            .do(onNext: { token in
                keychainManager.set(key: .accessToken, value: token)
                PictionManager.setToken(token)
                updater.refreshSession.onNext(())
            })
            .map { _ in keychainManager.get(key: .pincode).isEmpty }

        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame.asDriver(onErrorDriveWith: .empty())

        let activityIndicator = signInButtonAction.isExecuting

        let closeAction = input.closeBtnDidTap
            .map { false }

        let dismissViewController = Driver.merge(signInSuccess, closeAction)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            userInfo: userInfoSuccess,
            activityIndicator: activityIndicator,
            openSignUpViewController: input.signUpBtnDidTap,
            openFindPassword: input.findPasswordBtnDidTap,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            dismissViewController: dismissViewController,
            errorMsg: signInError,
            toastMessage: toastMessage
        )
    }
}
