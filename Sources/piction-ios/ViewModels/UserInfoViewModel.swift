//
//  UserInfoViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ViewModel
final class UserInfoViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
    }
}

// MARK: - Input & Output
extension UserInfoViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let userInfo: Driver<UserModel>
        let walletInfo: Driver<WalletModel>
        let toastMessage: Driver<String>
    }
}

// MARK: - ViewModel Build
extension UserInfoViewModel {
    func build(input: Input) -> Output {
        
        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 금액 갱신 시
        let refreshAmount = updater.refreshAmount
            .asDriver(onErrorDriveWith: .empty())

        // 유저 정보 호출
        let userInfoAction = Driver.merge(initialLoad, refreshSession, refreshAmount)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 유저 정보 호출 에러 시
        let userInfoError = userInfoAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 지갑 정보 호출
        let walletInfoAction = Driver.merge(initialLoad, refreshSession, refreshAmount)
            .map { WalletAPI.get }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 지갑 정보 호출 성공 시
        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        // 지갑 정보 호출 에러 시
        let walletInfoError = walletInfoAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 토스트 메시지
        let toastMessage = Driver.merge(
            userInfoError,
            walletInfoError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            toastMessage: toastMessage
        )
    }
}
