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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension SignInViewModel {
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
}

// MARK: - ViewModel Build
extension SignInViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keyboardManager, keychainManager) = (self.firebaseManager, self.updater, self.keyboardManager, self.keychainManager)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("로그인")
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
        let signInInfo = Driver.combineLatest(
            input.loginIdTextFieldDidInput,
            input.passwordTextFieldDidInput)
            { (loginId: $0, password: $1) }

        // 로그인 버튼 눌렀을 때 세션 생성 호출
        let signInAction = input.signInBtnDidTap
            .withLatestFrom(signInInfo)
            .map { SessionAPI.create(loginId: $0.loginId, password: $0.password, rememberme: true) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 세션 생성 성공 시
        let signInSuccess = signInAction.elements
            .map { try? $0.map(to: AuthenticationModel.self) }
            .map { $0?.accessToken ?? "" }
            .do(onNext: { token in
                keychainManager.set(key: .accessToken, value: token)
                PictionManager.setToken(token)
                updater.refreshSession.onNext(())
            })
            .map { _ in keychainManager.get(key: .pincode).isEmpty }

        // 세션 생성 실패 시 badRequest이면 에러 필드에 메시지 출력
        let errorMsg = signInAction.error
            .flatMap { response -> Driver<ErrorModel> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error):
                    return Driver.just(error)
                default:
                    return Driver.empty()
                }
            }

        // 세션 생성 실패 시 badRequest가 아니면 토스트 메시지 출력
        let toastMessage = signInAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field != nil:
                    return Driver.empty()
                default:
                    return Driver.just(errorType?.message ?? "")
                }
            }

        // 키보드로 인한 frame 변경 시
        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame
            .asDriver(onErrorDriveWith: .empty())

        // 로딩 뷰
        let activityIndicator = signInAction.isExecuting

        // 닫기 버튼 눌렀을 때
        let closeAction = input.closeBtnDidTap
            .map { false }

        // 세션 생성 성공 또는 닫기 버튼 눌렀을 때 dismiss
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
            errorMsg: errorMsg,
            toastMessage: toastMessage
        )
    }
}
