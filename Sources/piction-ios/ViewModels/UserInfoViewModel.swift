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

final class UserInfoViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let userInfo: Driver<UserModel>
        let walletInfo: Driver<WalletModel>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshAmount = updater.refreshAmount.asDriver(onErrorDriveWith: .empty())

        let userInfoAction = Driver.merge(initialLoad, refreshSession, refreshAmount)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoError = userInfoAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let walletInfoAction = Driver.merge(initialLoad, refreshSession, refreshAmount)
            .map { WalletAPI.get }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let walletInfoError = walletInfoAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        let toastMessage = Driver.merge(userInfoError, walletInfoError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            toastMessage: toastMessage
        )
    }
}
