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
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, refreshSession, refreshContent)
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

        let subscribingProjectsAction = Driver.merge(initialLoad, loadRetry)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.subscription(page: 1, size: 10))
                return Action.makeDriver(response)
            }

        let subscribingProjectsSuccess = subscribingProjectsAction.elements
            .flatMap { response -> Driver<[ProjectModel]> in
                guard let pageList = try? response.map(to: PageViewResponse<ProjectModel>.self) else { return Driver.empty() }
                return Driver.just(pageList.content ?? [])
            }

        let subscribingProjectsError = subscribingProjectsAction.error
            .flatMap { _ in Driver<[ProjectModel]>.just([]) }

        let subscribingProjectsEmpty = Driver.merge(subscribingProjectsSuccess, subscribingProjectsError)
            .filter { $0.count == 0 }
            .flatMap { [weak self] _ -> Driver<Void> in
                let header: HomeSection = .header(type: .notSubscribed)
                self?.sections = [header]
                return Driver.just(())
            }

        let subscribingPostLoad = Driver.merge(subscribingProjectsSuccess, subscribingProjectsError)
            .filter { $0.count > 0 }
            .flatMap { _ in Driver.just(()) }

        let subscribingPostAction = Driver.merge(subscribingPostLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(MyAPI.subscribingPosts(page: self.page + 1, size: 20))
                return Action.makeDriver(response)
            }

        let subscribingPostSuccess = subscribingPostAction.elements
            .flatMap { [weak self] response -> Driver<SectionType<HomeSection>> in
                guard
                    let `self` = self,
                    let pageList = try? response.map(to: PageViewResponse<SubscribingPostModel>.self),
                    let pageNumber = pageList.pageable?.pageNumber,
                    let totalPages = pageList.totalPages
                else {
                    return Driver.empty()
                }

                self.page = self.page + 1
                if pageNumber >= totalPages - 1 {
                    self.shouldInfiniteScroll = false
                }
                if self.page == 1 && pageList.content?.count == 0 {
                    return Driver.just(SectionType<HomeSection>.Section(title: "subscribingPosts", items: []))
                } else {
                    let subscribingPosts: [HomeSection] = (pageList.content ?? []).map { .subscribingPosts(item: $0) }
                    self.sections.append(contentsOf: subscribingPosts)
                    return Driver.just(SectionType<HomeSection>.Section(title: "subscribingPosts", items: self.sections))
                }
            }

        let subscribingPostError = subscribingPostAction.error
            .flatMap { _ -> Driver<SectionType<HomeSection>> in
                return Driver.just(SectionType<HomeSection>.Section(title: "subscribingPosts", items: []))
            }

        let subscribingPostsEmpty = Driver.merge(subscribingPostSuccess, subscribingPostError)
            .filter { $0.items.count == 0 }
            .flatMap { [weak self] _ -> Driver<Void> in
                let header: HomeSection = .header(type: .noPost)
                self?.sections = [header]
                return Driver.just(())
            }

        let trendingAction = Driver.merge(subscribingProjectsEmpty, subscribingPostsEmpty)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.trending)
                return Action.makeDriver(response)
            }

        let trendingSuccess = trendingAction.elements
            .flatMap{ [weak self] response -> Driver<SectionType<HomeSection>> in
                guard
                    let `self` = self,
                    let projects = try? response.map(to: [ProjectModel].self)
                else { return Driver.empty() }

                let trending: [HomeSection] = [.trending(item: projects)]
                self.sections.append(contentsOf: trending)
                self.shouldInfiniteScroll = false
                return Driver.just(SectionType<HomeSection>.Section(title: "trending", items: self.sections))
            }

        let homeSection = Driver.merge(subscribingPostSuccess, trendingSuccess)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(input.viewWillAppear)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let activityIndicator = Driver.merge(
            subscribingProjectsAction.isExecuting,
            subscribingPostAction.isExecuting,
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
