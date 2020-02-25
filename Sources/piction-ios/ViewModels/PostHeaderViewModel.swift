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
        let creatorBtnDidTap: Driver<Void>
    }

    struct Output {
        let headerInfo: Driver<(PostModel, UserModel)>
        let openCreatorProfileViewController: Driver<String>
    }

    func build(input: Input) -> Output {
        let (postItem, userInfo) = (self.postItem, self.userInfo)

        let headerInfo = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .map { (postItem, userInfo) }

        let openCreatorProfileViewController = input.creatorBtnDidTap
            .map { userInfo.loginId }
            .flatMap(Driver.from)

        return Output(
            headerInfo: headerInfo,
            openCreatorProfileViewController: openCreatorProfileViewController
        )
    }
}
