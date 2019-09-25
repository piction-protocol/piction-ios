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
    case initial
    case check
    case change
}

final class CheckPincodeViewModel: ViewModel {

    var style: CheckPincodeStyle = .initial

    init(style: CheckPincodeStyle) {
        self.style = style
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let closeBtnDidTap: Driver<Void>
        let signout: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<CheckPincodeStyle>
        let pincodeText: Driver<String>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear
            .flatMap { [weak self] _ -> Driver<CheckPincodeStyle> in
                return Driver.just(self?.style ?? .initial)
            }

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
