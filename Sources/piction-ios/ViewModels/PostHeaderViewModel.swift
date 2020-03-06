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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension PostHeaderViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let creatorBtnDidTap: Driver<Void>
    }
    struct Output {
        let headerInfo: Driver<(PostModel, UserModel)>
        let openCreatorProfileViewController: Driver<String>
    }
}

// MARK: - ViewModel Build
extension PostHeaderViewModel {
    func build(input: Input) -> Output {
        let (postItem, userInfo) = (self.postItem, self.userInfo)

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시
        // post정보와 유저 정보 전달
        let headerInfo = initialLoad
            .map { (postItem, userInfo) }

        // 크리에이터 눌렀을 때 크리에이터 정보 화면으로 이동
        let openCreatorProfileViewController = input.creatorBtnDidTap
            .map { userInfo.loginId }
            .flatMap(Driver.from)

        return Output(
            headerInfo: headerInfo,
            openCreatorProfileViewController: openCreatorProfileViewController
        )
    }
}
