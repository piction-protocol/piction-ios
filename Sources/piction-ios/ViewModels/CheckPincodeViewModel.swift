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
    case initial // 앱 최초 진입 시 인증
    case check // 결제 등 인증이 필요한 경우
    case change // pincode를 변경하기 전에 인증
}

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension CheckPincodeViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let closeBtnDidTap: Driver<Void>
        let signout: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let closeBtnStyle: Driver<CheckPincodeStyle>
        let inputPincode: Driver<(String, String)>
        let dismissViewController: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension CheckPincodeViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, keychainManager, style) = (self.firebaseManager, self.keychainManager, self.style)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("PIN인증")
            })

        // 닫기 버튼 스타일
        let closeBtnStyle = input.viewWillAppear
            .map { style }

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 현재 저장된 핀코드
        let currentPincode = initialLoad
            .map { keychainManager.get(key: .pincode) }

        // 로그아웃
        let signOutAction = input.signout
            .map { SessionAPI.delete }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 로그아웃 성공 시
        let signOutSuccess = signOutAction.elements
            .map { _ in Void() }

        // 로그아웃 성공하거나 닫기버튼 누를 때 dismiss
        let dismissViewController = Driver.merge(
            signOutSuccess,
            input.closeBtnDidTap)

        // 핀코드 입력 시 현재 핀코드와 함께 전달
        let inputPincode = Driver.combineLatest(currentPincode, input.pincodeTextFieldDidInput)

        return Output(
            viewWillAppear: viewWillAppear,
            closeBtnStyle: closeBtnStyle,
            inputPincode: inputPincode,
            dismissViewController: dismissViewController
        )
    }
}
