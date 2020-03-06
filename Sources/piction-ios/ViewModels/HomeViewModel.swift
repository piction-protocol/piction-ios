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

// MARK: - HomeHeaderType
enum HomeHeaderType {
    case notSubscribed
    case noPost
}

// MARK: - HomeSection
enum HomeSection {
    case header(type: HomeHeaderType)
    case subscribingPosts(item: SponsoringPostModel)
    case trending(item: [ProjectModel])
}

// MARK: - ViewModel
final class HomeViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol
    )

    var page = 0
    var sections: [HomeSection] = []
    var shouldInfiniteScroll = true

    let firebaseManager: FirebaseManagerProtocol
    let updater: UpdaterProtocol

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater) = dependency
    }
}

// MARK: - Input & Output
extension HomeViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let refreshControlDidRefresh: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let homeSection: Driver<SectionType<HomeSection>>
        let selectedIndexPath: Driver<IndexPath>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension HomeViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater) = (self.firebaseManager, self.updater)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("홈")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, pull to refresh 액션 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        let initialPage = Driver.merge(initialLoad, input.refreshControlDidRefresh, refreshSession, refreshContent)
            .do(onNext: { [weak self] in
                // 데이터 초기화
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, pull to refresh 액션 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 새로고침 필요 시
        // 구독중인 프로젝트 호출
        let subscribingProjectsAction = Driver.merge(initialPage, loadRetry)
            .map { SponsorAPI.projects(page: 1, size: 10) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독중인 프로젝트 호출 성공 시
        let subscribingProjectsSuccess = subscribingProjectsAction.elements
            .map { try? $0.map(to: PageViewResponse<ProjectModel>.self) }
            .map { $0?.content }
            .flatMap(Driver.from)

        // 구독중인 프로젝트 호출 에러 시
        let subscribingProjectsError = subscribingProjectsAction.error
            .flatMap { _ in Driver<[ProjectModel]>.just([]) }

        // 구독중인 프로젝트가 없을 때 헤더
        let subscribingProjectsEmpty = Driver.merge(subscribingProjectsSuccess, subscribingProjectsError)
            .filter { $0.isEmpty }
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] in
                self?.sections = [.header(type: .notSubscribed)]
            })

        // 구독중인 프로젝트가 있는 경우
        let subscribingPostLoad = Driver.merge(subscribingProjectsSuccess, subscribingProjectsError)
            .filter { $0.count > 0 }
            .map { _ in Void() }

        // 구독중인 프로젝트가 있는 경우, infinite scroll로 다음 페이지 호출 시
        // 구독중인 포스트 호출
        let subscribingPostAction = Driver.merge(subscribingPostLoad, loadNext)
            .map { SponsorAPI.latestPosts(page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독중인 포스트 호출 성공 시
        let subscribingPostSuccess = subscribingPostAction.elements
            .map { try? $0.map(to: PageViewResponse<SponsoringPostModel>.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList.pageable?.pageNumber,
                    let totalPages = pageList.totalPages
                else { return }

                // 페이지 증가
                self.page = self.page + 1

                // 현재 페이지가 전체페이지보다 작을때만 infiniteScroll 동작
                self.shouldInfiniteScroll = pageNumber < totalPages - 1
            })
            .map { ($0.content ?? []).map { .subscribingPosts(item: $0) } }
            .map { self.sections.append(contentsOf: $0)}
            .map { SectionType<HomeSection>.Section(title: "subscribingPosts", items: self.sections) }

        // 구독중인 포스트 호출 에러 시
        let subscribingPostError = subscribingPostAction.error
            .map { _ in SectionType<HomeSection>.Section(title: "subscribingPosts", items: []) }

        // 구독중인 포스트가 없을 때 헤더
        let subscribingPostsEmpty = Driver.merge(subscribingPostSuccess, subscribingPostError)
            .filter { $0.items.isEmpty }
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] _ in
                self?.sections = [.header(type: .noPost)]
            })

        // 구독중인 프로젝트가 없을 때, 구독중인 포스트가 없을 때
        // treding 호출
        let trendingAction = Driver.merge(subscribingProjectsEmpty, subscribingPostsEmpty)
            .map { ProjectAPI.trending }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // treding 호출 성공 시
        let trendingSuccess = trendingAction.elements
            .map { try? $0.map(to: [ProjectModel].self) }
            .flatMap(Driver.from)
            .map { [.trending(item: $0)] }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<HomeSection>.Section(title: "trending", items: self.sections) }
            .do(onNext: { [weak self] _ in
                self?.shouldInfiniteScroll = false
            })

        // 구독중인 포스트 목록, trending 목록 출력
        let homeSection = Driver.merge(subscribingPostSuccess, trendingSuccess)

        // pull to refresh 로딩 및 해제
        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(input.viewWillAppear)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            subscribingProjectsAction.isExecuting,
            trendingAction.isExecuting)

        return Output(
            viewWillAppear: viewWillAppear,
            viewDidAppear: input.viewDidAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            traitCollectionDidChange: input.traitCollectionDidChange,
            homeSection: homeSection,
            selectedIndexPath: input.selectedIndexPath,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator
        )
    }
}
