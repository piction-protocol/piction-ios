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
import RxPictionSDK

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

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let isLikeAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.isLike(uri: self?.uri ?? "", postId: self?.postItem.id ?? 0))
                return Action.makeDriver(response)
            }

        let isLikeSuccess = isLikeAction.elements
            .flatMap { response -> Driver<Bool> in
                guard let likeInfo = try? response.map(to: LikeModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(likeInfo.like ?? false)
            }

        let isLikeError = isLikeAction.error
            .flatMap { _ in Driver.just(false) }

        let isLikeInfo = Driver.merge(isLikeSuccess, isLikeError)

        let seriesPostItemsAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .filter { self.postItem.series != nil }
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
//                if self.postItem.series?.id == 0 {
//                    return Action.makeDriver(Action<ResponseData>.Element)
//                } else {
                let response = PictionSDK.rx.requestAPI(SeriesAPI.getPreviousAndNextPosts(uri: self.uri, seriesId: self.postItem.series?.id ?? 0, postId: self.postItem.id ?? 0, count: 5))
                    return Action.makeDriver(response)
//                }
            }

        let seriesPostItemsSuccess = seriesPostItemsAction.elements
            .flatMap { response -> Driver<[PostIndexModel]> in
                guard let postItems = try? response.map(to: [PostIndexModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(postItems)
            }

        let emptySeriesPostsItems = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .filter { self.postItem.series == nil }
            .flatMap { _ -> Driver<[PostIndexModel]> in
                return Driver.just([])
            }

        let seriesPostItems = Driver.merge(seriesPostItemsSuccess, emptySeriesPostsItems)

        let footerInfo = Driver.combineLatest(seriesPostItems, isLikeInfo)
            .flatMap { [weak self] (seriesPostItems, isLike) -> Driver<(PostModel, [PostIndexModel], Bool)> in
                        print(seriesPostItems)
                guard let `self` = self else { return Driver.empty() }
                return Driver.just((self.postItem, seriesPostItems, isLike))
            }

        let userInfoAction = Driver.merge(refreshContent, input.viewWillAppear, refreshSession)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
            }

        let userInfoError = userInfoAction.error
            .flatMap { response -> Driver<UserModel> in
                return Driver.just(UserModel.from([:])!)
            }

        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        let addLike = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.like(uri: self?.uri ?? "", postId: self?.postItem.id ?? 0))
                return Action.makeDriver(response)
            }

        let openSignInViewController = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .flatMap { _ in Driver.just(()) }

        let openSeriesPostViewController = input.seriesAllPostBtnDidTap
            .flatMap { [weak self] _ -> Driver<(String, Int)> in
                guard let `self` = self else { return Driver.empty() }

                return Driver.just((self.uri, self.postItem.series?.id ?? 0))
            }

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
