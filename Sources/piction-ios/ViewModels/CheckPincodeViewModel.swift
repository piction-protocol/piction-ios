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
            .map { self.style }

        let signOutAction = input.signout
            .map { SessionAPI.delete }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let signOutSuccess = signOutAction.elements
            .map { _ in Void() }

        let dismissViewController = Driver.merge(signOutSuccess, input.closeBtnDidTap)

        return Output(
            viewWillAppear: viewWillAppear,
            pincodeText: input.pincodeTextFieldDidInput,
            dismissViewController: dismissViewController
        )
    }
}
