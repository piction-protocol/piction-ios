//
//  SignUpCompleteViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

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

    struct Input {
        let viewWillAppear: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let dismissViewController: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, keychainManager, loginId) = (self.firebaseManager, self.keychainManager, self.loginId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("회원가입완료_\(loginId)")
            })

        let pincode = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .map { keychainManager.get(key: .pincode) }

        let dismissViewController = input.closeBtnDidTap
            .withLatestFrom(pincode)

        return Output(
            viewWillAppear: viewWillAppear,
            dismissViewController: dismissViewController
        )
    }
}
