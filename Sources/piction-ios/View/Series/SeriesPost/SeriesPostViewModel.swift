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
    var sections: [ContentsSection] = []
    var isDescending = true

    var loadNextTrigger = PublishSubject<Void>()
    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, uri, seriesId) = dependency
    }
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let sortBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let seriesInfo: Driver<SeriesModel>
        let seriesThumbnail: Driver<[String]>
        let contentList: Driver<SectionType<ContentsSection>>
        let isDescending: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<(String, Int)>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
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
                self.page = 0
                self.sections = []
                self.shouldInfiniteScroll = true
                return Driver.just(())
            }

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                return Driver.just(())
            }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let isSubscribingAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.getProjectSubscription(uri: self?.uri ?? ""))
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

        let isSubscribing = Driver.merge(isSubscribingSuccess, isSubscribingError)

        let loadSeriesInfoAction = Driver.merge(initialLoad, loadRetry)
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

        let loadSeriesThumbnailAction = Driver.merge(initialLoad, loadRetry)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SeriesAPI.getThumbnails(uri: self.uri, seriesId: self.seriesId))
                return Action.makeDriver(response)
            }

        let loadSeriesThumbnailSuccess = loadSeriesThumbnailAction.elements
            .flatMap { response -> Driver<[String]> in
                guard let seriesThumbnail = try? response.mapJSON() else {
                    return Driver.empty()
                }
                let test = seriesThumbnail as! [String]

                return Driver.just(test)
            }

        let loadSeriesPostsAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SeriesAPI.allSeriesPosts(uri: self.uri, seriesId: self.seriesId, page: self.page + 1, size: 20, isDescending: self.isDescending))
                return Action.makeDriver(response)
            }

        let loadSeriesPostsSuccess = loadSeriesPostsAction.elements
            .flatMap { response -> Driver<PageViewResponse<PostModel>> in
                guard let pageList = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(pageList)
            }

        let loadSeriesPostError = loadSeriesPostsAction.error
            .flatMap { _ in Driver.just(()) }

        let showErrorPopup = loadSeriesPostError

        let contentList = Driver.zip(loadSeriesPostsSuccess, isSubscribing)
            .flatMap { [weak self] (postList, isSubscribing) -> Driver<SectionType<ContentsSection>> in
                guard let `self` = self else { return Driver.empty() }
                if (postList.pageable?.pageNumber ?? 0) >= (postList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                self.page = self.page + 1
                let totalElements = postList.totalElements ?? 0
                let page = self.page - 1
                let numberOfElements = postList.size ?? 0

                let posts: [ContentsSection] = (postList.content ?? []).enumerated().map { .seriesPostList(post: $1, isSubscribing: isSubscribing, number: self.isDescending ? totalElements - page * numberOfElements - $0 : page * numberOfElements + ($0 + 1)) }

                self.sections.append(contentsOf: posts)

                return Driver.just(SectionType<ContentsSection>.Section(title: "post", items: self.sections))
            }

        let embedPostEmptyView = contentList
            .flatMap { [weak self] _ -> Driver<CustomEmptyViewStyle> in
                if ((self?.sections.count ?? 0) == 0) {
                    return Driver.just(.projectPostListEmpty)
                }
                return Driver.empty()
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

        let showActivityIndicator = initialLoad
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = contentList
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            seriesInfo: loadSeriesInfoSuccess,
            seriesThumbnail: loadSeriesThumbnailSuccess,
            contentList: contentList,
            isDescending: isDescending,
            embedEmptyViewController: embedPostEmptyView,
            selectedIndexPath: selectPostItem,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
