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
        let viewWillAppear: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        return Output(
            viewWillAppear: input.viewWillAppear,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
