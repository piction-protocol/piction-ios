//
//  SeriesPostViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK
import RxPictionSDK

final class SeriesPostViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int
    )

    private let updater: UpdaterProtocol
    let uri: String
    let seriesId: Int

    var page = 0
    var isWriter: Bool = false
    var shouldInfiniteScroll = true
    var sections: [ContentsItemType] = []
    var loadTrigger = PublishSubject<Void>()
    var isDescending = true

    init(dependency: Dependency) {
        (updater, uri, seriesId) = dependency
    }
    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let sortBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let seriesInfo: Driver<SeriesModel>
        let coverImage: Driver<String>
        let contentList: Driver<ContentsBySection>
        let isDescending: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<(String, Int)>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let isDescending = input.sortBtnDidTap
            .flatMap { [weak self] _ -> Driver<Bool> in
                guard let `self` = self else { return Driver.empty() }
                self.isDescending = !self.isDescending
                return Driver.just(self.isDescending)
            }

        let refreshSort = isDescending
            .flatMap { _ in Driver.just(()) }

        let initialLoad = Driver.merge(viewWillAppear, refreshContent, refreshSession, refreshSort)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 1
                self.sections = []
                self.shouldInfiniteScroll = true
                return Driver.just(())
            }

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                self.page = self.page + 1
                return Driver.just(())
            }

        let loadProjectInfoAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let loadProjectInfoSuccess = loadProjectInfoAction.elements
            .flatMap { response -> Driver<ProjectModel> in
                guard let projectInfo = try? response.map(to: ProjectModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(projectInfo)
            }

        let loadProjectInfoError = loadProjectInfoAction.error
            .flatMap { _ in Driver.just(ProjectModel.from([:])!) }

        let loadProjectInfo = Driver.merge(loadProjectInfoSuccess, loadProjectInfoError)

        let isSubscribingAction = Driver.merge(initialLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(FanPassAPI.isSubscription(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let isSubscribingSuccess = isSubscribingAction.elements
            .flatMap { response -> Driver<Bool> in
                guard let isSubscribing = try? response.map(to: SubscriptionModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(isSubscribing.fanPass != nil)
            }

        let isSubscribingError = isSubscribingAction.error
            .flatMap { _ in Driver.just(false) }

        let userInfoAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let currentUserInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
            }

        let currentUserInfoError = userInfoAction.error
            .flatMap { _ in Driver.just(UserModel.from([:])!) }

        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        let isWriter = Driver.combineLatest(loadProjectInfo, currentUserInfo)
            .flatMap { [weak self] (project, user) -> Driver<Bool> in
                self?.isWriter = project.user?.loginId == user.loginId
                return Driver.just(self?.isWriter ?? false)
            }

        let isSubscribing = Driver.merge(isSubscribingSuccess, isSubscribingError)

        let loadSeriesInfoAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SeriesAPI.get(uri: self.uri, seriesId: self.seriesId))
                return Action.makeDriver(response)
            }

        let loadSeriesInfoSuccess = loadSeriesInfoAction.elements
            .flatMap { response -> Driver<SeriesModel> in
                guard let seriesInfo = try? response.map(to: SeriesModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(seriesInfo)
            }

        let loadSeriesPostsAction = Driver.merge(initialLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SeriesAPI.allSeriesPosts(uri: self.uri, seriesId: self.seriesId, page: self.page, size: 10, isDescending: self.isDescending))
                return Action.makeDriver(response)
            }

        let loadSeriesPostsSuccess = loadSeriesPostsAction.elements
            .flatMap { response -> Driver<PageViewResponse<PostModel>> in
                guard let pageList = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(pageList)
            }

        let contentList = Driver.zip(loadSeriesPostsSuccess, isSubscribing)
            .flatMap { [weak self] (postList, isSubscribing) -> Driver<ContentsBySection> in
                guard let `self` = self else { return Driver.empty() }

                if (postList.pageable?.pageNumber ?? 0) >= (postList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }

                let totalElements = postList.totalElements ?? 0
                let page = self.page - 1
                let numberOfElements = postList.size ?? 0

                let posts: [ContentsItemType] = (postList.content ?? []).enumerated().map { .seriesPostList(post: $1, isSubscribing: isSubscribing, number: self.isDescending ? totalElements - page * numberOfElements - $0 : page * numberOfElements + ($0 + 1)) }

                self.sections.append(contentsOf: posts)

                return Driver.just(ContentsBySection.Section(title: "post", items: self.sections))
            }

        let embedPostEmptyView = contentList
            .flatMap { [weak self] _ -> Driver<CustomEmptyViewStyle> in
                if ((self?.sections.count ?? 0) == 0) {
                    return Driver.just(.projectPostListEmpty)
                }
                return Driver.empty()
            }

        let coverImage = contentList
            .flatMap { [weak self] postList -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                
                for section in self.sections {
                    switch section {
                    case .seriesPostList(let post, _, _):
                        if post.cover != nil {
                            return Driver.just(post.cover ?? "")
                        }
                    default:
                        return Driver.just("")
                    }
                }
                return Driver.just("")
            }

        let selectPostItem = input.selectedIndexPath
            .flatMap { [weak self] indexPath -> Driver<(String, Int)> in
                guard let `self` = self else { return Driver.empty() }
                guard self.sections.count > indexPath.row else { return Driver.empty() }

                switch self.sections[indexPath.row] {
                case .seriesPostList(let post, _, _):
                    return Driver.just((self.uri, post.id ?? 0))
                default:
                    return Driver.empty()
                }
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            seriesInfo: loadSeriesInfoSuccess,
            coverImage: coverImage,
            contentList: contentList,
            isDescending: isDescending,
            embedEmptyViewController: embedPostEmptyView,
            selectedIndexPath: selectPostItem
        )
    }
}
