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
    }


    func build(input: Input) -> Output {
        let userInfoAction = input.viewWillAppear
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
            }

        let walletInfoAction = input.viewWillAppear
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.wallet)
                return Action.makeDriver(response)
            }

        let walletInfoSuccess = walletInfoAction.elements
            .flatMap { response -> Driver<WalletModel> in
                guard let walletInfo = try? response.map(to: WalletModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(walletInfo)
            }

        let copyAddress = input.copyBtnDidTap
            .withLatestFrom(walletInfoSuccess)
            .flatMap { walletInfo -> Driver<String> in
                return Driver.just(walletInfo.publicKey ?? "")
            }


        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            copyAddress: copyAddress
        )
    }
}
