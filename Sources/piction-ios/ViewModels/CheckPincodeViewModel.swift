//
//  CheckPincodeViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

enum CheckPincodeStyle {
    case initial
    case check
    case change
}

final class CheckPincodeViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        KeychainManagerProtocol,
        CheckPincodeStyle
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let keychainManager: KeychainManagerProtocol
    var style: CheckPincodeStyle = .initial

    init(dependency: Dependency) {
        (firebaseManager, keychainManager, style) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let closeBtnDidTap: Driver<Void>
        let signout: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<CheckPincodeStyle>
        let inputPincode: Driver<(String, String)>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, keychainManager, style) = (self.firebaseManager, self.keychainManager, self.style)

        let viewWillAppear = input.viewWillAppear
            .map { style }
            .do(onNext: { _ in
                firebaseManager.screenName("PIN인증")
            })

        let loadPage = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let currentPincode = loadPage
            .map { keychainManager.get(key: .pincode) }

        let signOutAction = input.signout
            .map { SessionAPI.delete }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let signOutSuccess = signOutAction.elements
            .map { _ in Void() }

        let dismissViewController = Driver.merge(signOutSuccess, input.closeBtnDidTap)

        let inputPincode = Driver.combineLatest(currentPincode, input.pincodeTextFieldDidInput)

        return Output(
            viewWillAppear: viewWillAppear,
            inputPincode: inputPincode,
            dismissViewController: dismissViewController
        )
    }
}
