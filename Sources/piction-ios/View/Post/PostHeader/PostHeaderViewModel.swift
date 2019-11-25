//
//  PostHeaderViewModel.swift
//  PictionView
//
//  Created by jhseo on 11/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class PostHeaderViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        PostModel,
        UserModel
    )

    private let updater: UpdaterProtocol
    private let postItem: PostModel
    private let userInfo: UserModel

    init(dependency: Dependency) {
        (updater, postItem, userInfo) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
    }

    struct Output {
        let headerInfo: Driver<(PostModel, UserModel)>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let headerInfo = viewWillAppear
            .flatMap { [weak self] _ -> Driver<(PostModel, UserModel)>in
                guard let `self` = self else { return Driver.empty() }
                return Driver.just((self.postItem, self.userInfo))
            }

        return Output(
            headerInfo: headerInfo
        )
    }
}
