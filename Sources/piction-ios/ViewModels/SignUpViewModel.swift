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

// MARK: - ViewModel
final class SignUpViewModel: InjectableViewModel {

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
}

// MARK: - Input & Output
extension SignUpViewModel {
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
        let openSignUpComplete: Driver<String>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let activityIndicator: Driver<Bool>
        let errorMsg: Driver<ErrorModel>
    }
}

// MARK: - ViewModel Build
extension SignUpViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keyboardManager, keychainManager) = (self.firebaseManager, self.updater, self.keyboardManager, self.keychainManager)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("회원가입")
                // 키보드가 올라오는지 모니터링
                keyboardManager.beginMonitoring()
            })

        // 화면이 사라지기 전에
        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                // 키보드 모니터링 중단
                keyboardManager.stopMonitoring()
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 유저 정보 호출
        let userInfoAction = initialLoad
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 입력한 유저 정보
        let signUpInfo = Driver.combineLatest(
            input.loginIdTextFieldDidInput,
            input.emailTextFieldDidInput,
            input.passwordTextFieldDidInput,
            input.passwordCheckTextFieldDidInput,
            input.nicknameTextFieldDidInput)
            { (loginId: $0, email: $1, password: $2, passwordCheck: $3, username: $4) }

        // 회원가입 버튼 누르면 회원가입 호출
        let signUpAction = input.signUpBtnDidTap
            .withLatestFrom(signUpInfo)
            .map { UserAPI.signup(loginId: $0.loginId, email: $0.email, username: $0.username, password: $0.password, passwordCheck: $0.passwordCheck) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 회원가입 실패 시 badRequest일 때만
        let signUpError = signUpAction.error
            .flatMap { response -> Driver<ErrorModel> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error):
                    return Driver.just(error)
                default:
                    return Driver.empty()
                }
            }

        // 세션 생성 호출
        let signInAction = signUpAction.elements
            .withLatestFrom(signUpInfo)
            .map { SessionAPI.create(loginId: $0.loginId, password: $0.password, rememberme: true) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 세션 생성 호출 성공 시
        let signInSuccess = signInAction.elements
            .map { try? $0.map(to: AuthenticationViewResponse.self) }
            .map { $0?.accessToken ?? "" }
            .do(onNext: { token in
                keychainManager.set(key: .accessToken, value: token)
                PictionManager.setToken(token)
                updater.refreshSession.onNext(())
            })
            .withLatestFrom(input.loginIdTextFieldDidInput)

        // 키보드로 인한 frame 변경 시
        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame
            .asDriver(onErrorDriveWith: .empty())

        // 로딩 뷰
        let activityIndicator = signInAction.isExecuting

        // 입력 시 에러 메시지 필드 초기화
        let clearErrorMsg = Driver.merge(
            input.loginIdTextFieldDidInput,
            input.emailTextFieldDidInput,
            input.passwordTextFieldDidInput,
            input.passwordCheckTextFieldDidInput,
            input.nicknameTextFieldDidInput)
            .map { _ in ErrorModel.from([:])! }

        // 에러 메시지 필드에 출력
        let errorMsg = Driver.merge(signUpError, clearErrorMsg)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            userInfo: userInfoSuccess,
            signUpBtnEnable: input.agreeBtnDidTap,
            openSignUpComplete: signInSuccess,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            activityIndicator: activityIndicator,
            errorMsg: errorMsg
        )
    }
}
