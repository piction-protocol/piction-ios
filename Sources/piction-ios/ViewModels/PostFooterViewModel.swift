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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension PostFooterViewModel {
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
}

// MARK: - ViewModel Build
extension PostFooterViewModel {
    func build(input: Input) -> Output {
        let (uri, postItem) = (self.uri, self.postItem)

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시
        // 좋아요 여부 호출
        let isLikeAction = initialLoad
            .map { PostAPI.getLike(uri: uri, postId: postItem.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 좋아요 여부 호출 성공 시
        let isLikeSuccess = isLikeAction.elements
            .map { try? $0.map(to: LikeModel.self) }
            .map { $0?.like }
            .flatMap(Driver.from)

        // 좋아요 여부 호출 에러 시
        let isLikeError = isLikeAction.error
            .map { _ in false }

        // 좋아요 여부
        let isLike = Driver.merge(isLikeSuccess, isLikeError)

        // 최초 진입 시
        // 시리즈 포스트 링크 호출
        let seriesPostItemsAction = initialLoad
            .filter { postItem.series != nil }
            .map { PostAPI.getSeriesLinks(uri: uri, postId: postItem.id ?? 0, count: 2) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 시리즈 포스트 링크 호출 성공 시
        let seriesPostItemsSuccess = seriesPostItemsAction.elements
            .map { try? $0.map(to: [PostIndexModel].self) }
            .flatMap(Driver.from)

        // 최초 진입 시
        // 시리즈가 없는 경우
        let emptySeriesPostsItems = initialLoad
            .filter { postItem.series == nil }
            .map { _ in [PostIndexModel]() }

        // 시리즈 포스트
        let seriesPostItems = Driver.merge(seriesPostItemsSuccess, emptySeriesPostsItems)

        // 시리즈 포스트와 좋아요 여부를 전달
        let footerInfo = Driver.zip(seriesPostItems, isLike)
            .map { (postItem, $0, $1) }

        // 최초 진입 시
        // 유저 정보 호출
        let userInfoAction = initialLoad
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 유저 정보 호출 에러 시
        let userInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        // 유저 정보
        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        // 좋아요 버튼 눌렀을 때
        let addLikeAction = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .map { _ in postItem.id ?? 0 }
            .map { PostAPI.like(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 로그인 안된 상태에서 좋아요 버튼 눌렀을 때 로그인 화면 출력
        let openSignInViewController = input.likeBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        // 포스트 전체 목록 버튼 눌렀을 때 시리즈 포스트 목록으로 이동
        let openSeriesPostViewController = input.seriesAllPostBtnDidTap
            .map { (uri, postItem.series?.id ?? 0) }

        // 시리즈 포스트를 눌렀을 때 해당 postId로 화면 갱신
        let selectSeriesPostItem = input.selectedIndexPath

        return Output(
            footerInfo: footerInfo,
            addLike: addLikeAction.isExecuting,
            selectSeriesPostItem: selectSeriesPostItem,
            openSignInViewController: openSignInViewController,
            openSeriesPostViewController: openSeriesPostViewController
        )
    }
}
