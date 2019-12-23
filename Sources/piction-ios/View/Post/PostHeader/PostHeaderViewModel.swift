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
        let (postItem, userInfo) = (self.postItem, self.userInfo)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let headerInfo = viewWillAppear
            .flatMap { _ -> Driver<(PostModel, UserModel)>in
                return Driver.just((postItem, userInfo))
            }

        return Output(
            headerInfo: headerInfo
        )
    }
}
