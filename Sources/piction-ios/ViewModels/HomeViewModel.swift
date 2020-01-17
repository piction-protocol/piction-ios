//
//  HomeViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK
import RxDataSources

enum HomeHeaderType {
    case notSubscribed
    case noPost
}

enum HomeSection {
    case header(type: HomeHeaderType)
    case subscribingPosts(item: SubscribingPostModel)
    case trending(item: [ProjectModel])
}

final class HomeViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    var page = 0
    var sections: [HomeSection] = []
    var shouldInfiniteScroll = true

    let updater: UpdaterProtocol

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let homeSection: Driver<SectionType<HomeSection>>
        let selectedIndexPath: Driver<IndexPath>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let initialPage = Driver.merge(initialLoad, input.refreshControlDidRefresh, refreshSession, refreshContent)
            .do(onNext: { [weak self] in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let subscribingProjectsAction = Driver.merge(initialPage, loadRetry)
            .map { SubscriberAPI.projects(page: 1, size: 10) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscribingProjectsSuccess = subscribingProjectsAction.elements
            .map { try? $0.map(to: PageViewResponse<ProjectModel>.self) }
            .map { $0?.content }
            .flatMap(Driver.from)

        let subscribingProjectsError = subscribingProjectsAction.error
            .flatMap { _ in Driver<[ProjectModel]>.just([]) }

        let subscribingProjectsEmpty = Driver.merge(subscribingProjectsSuccess, subscribingProjectsError)
            .filter { $0.isEmpty }
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] in
                self?.sections = [.header(type: .notSubscribed)]
            })

        let subscribingPostLoad = Driver.merge(subscribingProjectsSuccess, subscribingProjectsError)
            .filter { $0.count > 0 }
            .map { _ in Void() }

        let subscribingPostAction = Driver.merge(subscribingPostLoad, loadNext)
            .map { SubscriberAPI.latestPosts(page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscribingPostSuccess = subscribingPostAction.elements
            .map { try? $0.map(to: PageViewResponse<SubscribingPostModel>.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] pageList in
                guard
                    let page = self?.page,
                    let pageNumber = pageList.pageable?.pageNumber,
                    let totalPages = pageList.totalPages
                else { return }

                self?.page = page + 1
                if pageNumber >= totalPages - 1 {
                    self?.shouldInfiniteScroll = false
                }
            })
            .map { ($0.content ?? []).map { .subscribingPosts(item: $0) } }
            .map { self.sections.append(contentsOf: $0)}
            .map { SectionType<HomeSection>.Section(title: "subscribingPosts", items: self.sections) }

        let subscribingPostError = subscribingPostAction.error
            .map { _ in SectionType<HomeSection>.Section(title: "subscribingPosts", items: []) }

        let subscribingPostsEmpty = Driver.merge(subscribingPostSuccess, subscribingPostError)
            .filter { $0.items.isEmpty }
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] _ in
                self?.sections = [.header(type: .noPost)]
            })

        let trendingAction = Driver.merge(subscribingProjectsEmpty, subscribingPostsEmpty)
            .map { ProjectAPI.trending }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let trendingSuccess = trendingAction.elements
            .map { try? $0.map(to: [ProjectModel].self) }
            .flatMap(Driver.from)
            .map { [.trending(item: $0)] }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<HomeSection>.Section(title: "trending", items: self.sections) }
            .do(onNext: { [weak self] _ in
                self?.shouldInfiniteScroll = false
            })

        let homeSection = Driver.merge(subscribingPostSuccess, trendingSuccess)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(input.viewWillAppear)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let activityIndicator = Driver.merge(
            subscribingProjectsAction.isExecuting,
            trendingAction.isExecuting)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            homeSection: homeSection,
            selectedIndexPath: input.selectedIndexPath,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator
        )
    }
}
