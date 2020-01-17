//
//  PostFooterViewModel.swift
//  PictionView
//
//  Created by jhseo on 11/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class PostFooterViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        String,
        PostModel
    )

    private let updater: UpdaterProtocol
    private let uri: String
    let postItem: PostModel

    init(dependency: Dependency) {
        (updater, uri, postItem) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let likeBtnDidTap: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let seriesAllPostBtnDidTap: Driver<Void>
    }

    struct Output {
        let footerInfo: Driver<(PostModel, [PostIndexModel], Bool)>
        let addLike: Driver<Bool>
        let selectSeriesPostItem: Driver<IndexPath>
        let openSignInViewController: Driver<Void>
        let openSeriesPostViewController: Driver<(String, Int)>
    }

    func build(input: Input) -> Output {
        let (uri, postItem) = (self.uri, self.postItem)

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let isLikeAction = initialLoad
            .map { PostAPI.getLike(uri: uri, postId: postItem.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let isLikeSuccess = isLikeAction.elements
            .map { try? $0.map(to: LikeModel.self) }
            .map { $0?.like }
            .flatMap(Driver.from)

        let isLikeError = isLikeAction.error
            .map { _ in false }

        let isLikeInfo = Driver.merge(isLikeSuccess, isLikeError)

        let seriesPostItemsAction = initialLoad
            .filter { postItem.series != nil }
            .map { PostAPI.getSeriesLinks(uri: uri, postId: postItem.id ?? 0, count: 2) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let seriesPostItemsSuccess = seriesPostItemsAction.elements
            .map { try? $0.map(to: [PostIndexModel].self) }
            .flatMap(Driver.from)

        let emptySeriesPostsItems = initialLoad
            .filter { postItem.series == nil }
            .map { _ in [PostIndexModel]() }

        let seriesPostItems = Driver.merge(seriesPostItemsSuccess, emptySeriesPostsItems)

        let footerInfo = Driver.zip(seriesPostItems, isLikeInfo)
            .map { (postItem, $0, $1) }

        let userInfoAction = initialLoad
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let userInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        let addLike = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .map { _ in postItem.id ?? 0 }
            .map { PostAPI.like(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let openSignInViewController = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let openSeriesPostViewController = input.seriesAllPostBtnDidTap
            .map { (uri, postItem.series?.id ?? 0) }

        let selectSeriesPostItem = input.selectedIndexPath

        return Output(
            footerInfo: footerInfo,
            addLike: addLike.isExecuting,
            selectSeriesPostItem: selectSeriesPostItem,
            openSignInViewController: openSignInViewController,
            openSeriesPostViewController: openSeriesPostViewController
        )
    }
}
