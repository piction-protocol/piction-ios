//
//  SignUpCompleteViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

// MARK: - ViewModel
final class SignUpCompleteViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        KeychainManagerProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let keychainManager: KeychainManagerProtocol
    private let loginId: String

    init(dependency: Dependency) {
        (firebaseManager, keychainManager, loginId) = dependency
    }
}

// MARK: - Input & Output
extension SignUpCompleteViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let dismissViewController: Driver<String>
    }
}

// MARK: - ViewModel Build
extension SignUpCompleteViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, keychainManager, loginId) = (self.firebaseManager, self.keychainManager, self.loginId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("회원가입완료_\(loginId)")
            })

        // 확인 버튼 눌렀을 때
        let dismissViewController = input.closeBtnDidTap
            .map { keychainManager.get(key: .pincode) }

        return Output(
            viewWillAppear: viewWillAppear,
            dismissViewController: dismissViewController
        )
    }
}
