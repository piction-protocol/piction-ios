//
//  CheckPincodeViewModel.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CheckPincodeViewModel: ViewModel {
    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let closeBtnDidTap: Driver<Void>
        let signout: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let pincodeText: Driver<String>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear

        let signOutAction = input.signout
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SessionsAPI.delete)
                return Action.makeDriver(response)
            }

        let signOutSuccess = signOutAction.elements
            .flatMap { _ -> Driver<Void> in
                return Driver.just(())
            }

        let dismissViewController = Driver.merge(signOutSuccess, input.closeBtnDidTap)


        return Output(
            viewWillAppear: viewWillAppear,
            pincodeText: input.pincodeTextFieldDidInput,
            dismissViewController: dismissViewController
        )
    }
}
