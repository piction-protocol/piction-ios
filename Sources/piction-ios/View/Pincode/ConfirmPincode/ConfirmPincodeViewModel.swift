//
//  ConfirmPincodeViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

final class ConfirmPincodeViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    private let updater: UpdaterProtocol
    var inputPincode = ""

    init(dependency: Dependency) {
        (updater, inputPincode) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let changeComplete: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let pincodeText: Driver<String>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {

        let dismissViewController = input.changeComplete
            .flatMap { [weak self] _ -> Driver<Void> in
                self?.updater.refreshSession.onNext(())
                return Driver.just(())
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            pincodeText: input.pincodeTextFieldDidInput,
            dismissViewController: dismissViewController
        )
    }
}
