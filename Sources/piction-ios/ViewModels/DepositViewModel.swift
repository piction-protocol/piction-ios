//
//  DepositViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 13/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ViewModel
final class DepositViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager) = dependency
    }

    var loadRetryTrigger = PublishSubject<Void>()
}

// MARK: - Input & Output
extension DepositViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let copyBtnDidTap: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let userInfo: Driver<UserModel>
        let walletInfo: Driver<WalletModel>
        let copyAddress: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension DepositViewModel {
    func build(input: Input) -> Output {
        let firebaseManager = self.firebaseManager

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("마이페이지_입금")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 새로고침 필요 시
        // 유저 정보 호출
        let userInfoAction = Driver.merge(initialLoad, loadRetry)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 최초 진입 시, 새로고침 필요 시
        // 지갑 정보 호출
        let walletInfoAction = Driver.merge(initialLoad, loadRetry)
            .map { WalletAPI.get }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 지갑 정보 호출 성공 시
        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        // 지갑 정보 호출 에러 시
        let walletInfoError = walletInfoAction.error
            .map { _ in Void() }

        // 에러 팝업 출력
        let showErrorPopup = walletInfoError

        // 주소 복사 버튼 눌렀을 때
        let copyAddress = input.copyBtnDidTap
            .withLatestFrom(walletInfoSuccess)
            .map { $0.publicKey }
            .flatMap(Driver.from)

        // 로딩 뷰
        let activityIndicator = walletInfoAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            copyAddress: copyAddress,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
