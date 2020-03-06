//
//  ConfirmPincodeViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

// MARK: - ViewModel
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
    private let inputedPincode: String // CheckPincode에서 입력한 핀코드

    init(dependency: Dependency) {
        (firebaseManager, updater, keychainManager, inputedPincode) = dependency
    }
}

// MARK: - Input & Output
extension ConfirmPincodeViewModel {
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
}

// MARK: - ViewModel Build
extension ConfirmPincodeViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keychainManager, inputedPincode) = (self.firebaseManager, self.updater, self.keychainManager, self.inputedPincode)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("PIN재입력")
            })

        // 핀코드 입력 시 현재 저장된 핀코드와 함꼐 전달
        let inputPincode = input.pincodeTextFieldDidInput
            .map { (inputedPincode, $0) }

        // 핀코드 저장 완료 시
        let dismissViewController = input.changeComplete
            .do(onNext: { _ in
                // 키체인에 저장
                keychainManager.set(key: .pincode, value: inputedPincode)
                // 세션 업데이트
                updater.refreshSession.onNext(())
            })

        return Output(
            viewWillAppear: viewWillAppear,
            inputPincode: inputPincode,
            dismissViewController: dismissViewController
        )
    }
}
