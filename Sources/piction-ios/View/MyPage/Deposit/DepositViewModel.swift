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

final class DepositViewModel: ViewModel {

    var loadRetryTrigger = PublishSubject<Void>()

    init() {}

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

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let userInfoAction = Driver.merge(viewWillAppear, loadRetry)
            .map { UsersAPI.me }
            .map { PictionSDK.rx.requestAPI($0) }
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let walletInfoAction = Driver.merge(viewWillAppear, loadRetry)
            .map { MyAPI.wallet }
            .map { PictionSDK.rx.requestAPI($0) }
            .flatMap(Action.makeDriver)

        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        let walletInfoError = walletInfoAction.error
            .map { _ in Void() }

        let showErrorPopup = walletInfoError

        let copyAddress = input.copyBtnDidTap
            .withLatestFrom(walletInfoSuccess)
            .map { $0.publicKey }
            .flatMap(Driver.from)

        let activityIndicator = walletInfoAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            copyAddress: copyAddress,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
