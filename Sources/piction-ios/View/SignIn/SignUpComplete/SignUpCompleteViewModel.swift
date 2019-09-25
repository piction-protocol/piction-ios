//
//  SignUpCompleteViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

final class SignUpCompleteViewModel: ViewModel {

    init() {}

    struct Input {
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        return Output(
            dismissViewController: input.closeBtnDidTap
        )
    }
}
