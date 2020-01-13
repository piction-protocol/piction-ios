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
        let contentList: Driver<SectionType<ContentsSection>>
        let isDescending: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let (uri, seriesId) = (self.uri, self.seriesId)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let isDescending = input.sortBtnDidTap
            .map { self.isDescending = !self.isDescending }
            .map { self.isDescending }

        let refreshSort = isDescending
            .map { _ in Void() }

        let initialLoad = Driver.merge(viewWillAppear, refreshContent, refreshSession, refreshSort)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let isSubscribingAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .map { ProjectsAPI.getProjectSubscription(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let isSubscribingSuccess = isSubscribingAction.elements
            .map { try? $0.map(to: SubscriptionModel.self) }
            .map { $0?.fanPass != nil }
            .flatMap(Driver.from)

        let isSubscribingError = isSubscribingAction.error
            .map { _ in false }

        let isSubscribing = Driver.merge(isSubscribingSuccess, isSubscribingError)

        let loadSeriesInfoAction = Driver.merge(initialLoad, loadRetry)
            .map { SeriesAPI.get(uri: uri, seriesId: seriesId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadSeriesInfoSuccess = loadSeriesInfoAction.elements
            .map { try? $0.map(to: SeriesModel.self) }
            .flatMap(Driver.from)

        let loadSeriesPostsAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .map { SeriesAPI.allSeriesPosts(uri: uri, seriesId: seriesId, page: self.page + 1, size: 20, isDescending: self.isDescending) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadSeriesPostsSuccess = loadSeriesPostsAction.elements
            .map { try? $0.map(to: PageViewResponse<PostModel>.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] postList in
                guard
                    let page = self?.page,
                    let pageNumber = postList.pageable?.pageNumber,
                    let totalPages = postList.totalPages
                else { return }

                self?.shouldInfiniteScroll = pageNumber < totalPages - 1
                self?.page = page + 1
            })

        let loadSeriesPostError = loadSeriesPostsAction.error
            .map { _ in Void() }

        let showErrorPopup = loadSeriesPostError

        let contentList = Driver.zip(loadSeriesPostsSuccess, isSubscribing)
            .map { [weak self] (postList, isSubscribing) -> [ContentsSection] in
                guard
                    let `self` = self,
                    let totalElements = postList.totalElements,
                    let numberOfElements = postList.size
                else { return [] }

                let page = self.page - 1

                return (postList.content ?? []).enumerated()
                    .map { .seriesPostList(post: $1, isSubscribing: isSubscribing, number: self.isDescending ? totalElements - page * numberOfElements - $0 : page * numberOfElements + ($0 + 1)) }
            }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        let embedPostEmptyView = contentList
            .filter { $0.items.isEmpty }
            .map { _ in .projectPostListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let activityIndicator = loadSeriesInfoAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            seriesInfo: loadSeriesInfoSuccess,
            contentList: contentList,
            isDescending: isDescending,
            embedEmptyViewController: embedPostEmptyView,
            selectedIndexPath: input.selectedIndexPath,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
