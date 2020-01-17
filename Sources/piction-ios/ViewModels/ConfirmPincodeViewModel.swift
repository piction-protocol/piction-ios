//
//  ConfirmPincodeViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

final class ConfirmPincodeViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        KeychainManagerProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let keychainManager: KeychainManagerProtocol
    private let inputedPincode: String

    init(dependency: Dependency) {
        (firebaseManager, updater, keychainManager, inputedPincode) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let changeComplete: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let inputPincode: Driver<(String, String)>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, keychainManager, inputedPincode) = (self.firebaseManager, self.updater, self.keychainManager, self.inputedPincode)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("PIN재입력")
            })

        let inputPincode = input.pincodeTextFieldDidInput
            .map { (inputedPincode, $0) }

        let dismissViewController = input.changeComplete
            .do(onNext: { _ in
                keychainManager.set(key: .pincode, value: inputedPincode)
                updater.refreshSession.onNext(())
            })

        return Output(
            viewWillAppear: viewWillAppear,
            inputPincode: inputPincode,
            dismissViewController: dismissViewController
        )
    }
}
