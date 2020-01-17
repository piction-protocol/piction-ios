//
//  RegisterPincodeViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

final class RegisterPincodeViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let pincodeTextFieldDidInput: Driver<String>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let pincodeText: Driver<String>
        let openRecommendPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let firebaseManager = self.firebaseManager

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("새PIN설정")
            })
        return Output(
            viewWillAppear: viewWillAppear,
            pincodeText: input.pincodeTextFieldDidInput,
            openRecommendPopup: input.closeBtnDidTap
        )
    }
}
