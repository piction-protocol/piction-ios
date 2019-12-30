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
        let uri = self.uri

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let isLikeAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .map { PostsAPI.isLike(uri: uri, postId: self.postItem.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let isLikeSuccess = isLikeAction.elements
            .map { try? $0.map(to: LikeModel.self) }
            .map { $0?.like }
            .flatMap(Driver.from)

        let isLikeError = isLikeAction.error
            .map { _ in false }

        let isLikeInfo = Driver.merge(isLikeSuccess, isLikeError)

        let seriesPostItemsAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .filter { self.postItem.series != nil }
            .map { SeriesAPI.getPreviousAndNextPosts(uri: uri, seriesId: self.postItem.series?.id ?? 0, postId: self.postItem.id ?? 0, count: 2) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let seriesPostItemsSuccess = seriesPostItemsAction.elements
            .map { try? $0.map(to: [PostIndexModel].self) }
            .flatMap(Driver.from)

        let emptySeriesPostsItems = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .filter { self.postItem.series == nil }
            .map { _ in [PostIndexModel]() }

        let seriesPostItems = Driver.merge(seriesPostItemsSuccess, emptySeriesPostsItems)

        let footerInfo = Driver.zip(seriesPostItems, isLikeInfo)
            .map { (self.postItem, $0, $1) }

        let userInfoAction = Driver.merge(refreshContent, viewWillAppear, refreshSession)
            .map { UsersAPI.me }
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
            .map { _ in self.postItem.id ?? 0 }
            .map { PostsAPI.like(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let openSignInViewController = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let openSeriesPostViewController = input.seriesAllPostBtnDidTap
            .map { (uri, self.postItem.series?.id ?? 0) }

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
