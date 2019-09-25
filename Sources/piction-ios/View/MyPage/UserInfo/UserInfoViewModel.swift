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
import RxPictionSDK

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
        let userInfo: Driver<UserModel>
        let walletInfo: Driver<WalletModel>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshAmount = updater.refreshAmount.asDriver(onErrorDriveWith: .empty())

        let userInfoAction = Driver.merge(viewWillAppear, refreshSession, refreshAmount)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userInfoError = userInfoAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                print(userInfo)
                return Driver.just(userInfo)
            }

        let walletInfoAction = Driver.merge(viewWillAppear, refreshSession, refreshAmount)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.wallet)
                return Action.makeDriver(response)
            }

        let walletInfoError = walletInfoAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let walletInfoSuccess = walletInfoAction.elements
            .flatMap { response -> Driver<WalletModel> in
                guard let walletInfo = try? response.map(to: WalletModel.self) else {
                    return Driver.empty()
                }
                print(walletInfo)
                return Driver.just(walletInfo)
            }

        let showToast = Driver.merge(userInfoError, walletInfoError)

        return Output(
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            showToast: showToast
        )
    }
}
