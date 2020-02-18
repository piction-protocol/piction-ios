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
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let uri: String
    private let seriesId: Int

    var page = 0
    var isWriter: Bool = false
    var shouldInfiniteScroll = true
    var sections: [ContentsSection] = []
    var isDescending = true

    var loadNextTrigger = PublishSubject<Void>()
    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, seriesId) = dependency
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
        let selectedIndexPath: Driver<(String, IndexPath)>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, uri, seriesId) = (self.firebaseManager, self.uri, self.seriesId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("시리즈상세_\(uri)_\(seriesId)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let isDescending = input.sortBtnDidTap
            .map { self.isDescending = !self.isDescending }
            .map { self.isDescending }

        let refreshSort = isDescending
            .map { _ in Void() }

        let initialPage = Driver.merge(initialLoad, refreshContent, refreshSession, refreshSort)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let subscriptionInfoAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { SponsorshipPlanAPI.getSponsoredPlan(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        let SubscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, SubscriptionInfoError)

        let loadSeriesInfoAction = Driver.merge(initialPage, loadRetry)
            .map { SeriesAPI.get(uri: uri, seriesId: seriesId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadSeriesInfoSuccess = loadSeriesInfoAction.elements
            .map { try? $0.map(to: SeriesModel.self) }
            .flatMap(Driver.from)

        let loadSeriesPostsAction = Driver.merge(initialPage, loadNext, loadRetry)
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

        let contentList = loadSeriesPostsSuccess
            .withLatestFrom(subscriptionInfo) { ($0, $1) }
            .map { [weak self] (postList, subscriptionInfo) -> [ContentsSection] in
                guard
                    let `self` = self,
                    let totalElements = postList.totalElements,
                    let numberOfElements = postList.size
                else { return [] }

                let page = self.page - 1

                return (postList.content ?? []).enumerated()
                    .map { .seriesPostList(post: $1, subscriptionInfo: subscriptionInfo, number: self.isDescending ? totalElements - page * numberOfElements - $0 : page * numberOfElements + ($0 + 1)) }
            }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        let selectedIndexPath = input.selectedIndexPath
            .map { (uri, $0) }

        let embedPostEmptyView = contentList
            .filter { $0.items.isEmpty }
            .map { _ in .projectPostListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let activityIndicator = loadSeriesInfoAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            seriesInfo: loadSeriesInfoSuccess,
            contentList: contentList,
            isDescending: isDescending,
            embedEmptyViewController: embedPostEmptyView,
            selectedIndexPath: selectedIndexPath,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
