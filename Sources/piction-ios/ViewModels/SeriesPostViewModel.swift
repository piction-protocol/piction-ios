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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension SeriesPostViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let viewDidLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let sortBtnDidTap: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let viewDidLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let seriesInfo: Driver<SeriesModel>
        let seriesPostList: Driver<SectionType<ContentsSection>>
        let isDescending: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<(String, IndexPath)>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension SeriesPostViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, uri, seriesId) = (self.firebaseManager, self.uri, self.seriesId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("시리즈상세_\(uri)_\(seriesId)")
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

        // 정렬 버튼 눌렀을 때
        let isDescending = input.sortBtnDidTap
            .map { self.isDescending = !self.isDescending }
            .map { self.isDescending }

        // 정렬 시
        let refreshSort = isDescending
            .map { _ in Void() }

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 정렬 시
        let initialPage = Driver.merge(initialLoad, refreshSession, refreshContent, refreshSort)
            .do(onNext: { [weak self] _ in
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

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 정렬 시, infinite scroll로 다음 페이지 호출, 새로고침 필요 시
        // 구독중인 멤버십 호출
        let subscriptionInfoAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독중인 멤버십 호출 성공 시
        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        // 구독중인 멤버십 호출 에러 시
        let SubscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        // 구독중인 멤버십
        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, SubscriptionInfoError)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 정렬 시, 새로고침 필요 시
        // 시리즈 정보 호출
        let loadSeriesInfoAction = Driver.merge(initialPage, loadRetry)
            .map { SeriesAPI.get(uri: uri, seriesId: seriesId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 시리즈 정보 호출 성공 시
        let loadSeriesInfoSuccess = loadSeriesInfoAction.elements
            .map { try? $0.map(to: SeriesModel.self) }
            .flatMap(Driver.from)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 정렬 시, infinite scroll로 다음 페이지 호출, 새로고침 필요 시
        // 시리즈 포스트 목록 호출
        let loadSeriesPostsAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { SeriesAPI.allSeriesPosts(uri: uri, seriesId: seriesId, page: self.page + 1, size: 20, isDescending: self.isDescending) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 시리즈 포스트 목록 호출 성공 시
        let loadSeriesPostsSuccess = loadSeriesPostsAction.elements
            .map { try? $0.map(to: PageViewResponse<PostModel>.self) }
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

        // 시리즈 포스트 목록 호출 에러 시
        let loadSeriesPostError = loadSeriesPostsAction.error
            .map { _ in Void() }

        // 에러 팝업 출력
        let showErrorPopup = loadSeriesPostError

        // 시리즈 포스트 목록
        let seriesPostList = loadSeriesPostsSuccess
            .withLatestFrom(subscriptionInfo) { ($0, $1) }
            .map { [weak self] (postList, subscriptionInfo) -> [ContentsSection] in
                guard
                    let `self` = self,
                    let totalElements = postList.totalElements,
                    let numberOfElements = postList.size
                else { return [] }

                // 페이지 증가
                let page = self.page - 1

                // 정렬에 따라 목록 정렬
                return (postList.content ?? []).enumerated()
                    .map { .seriesPostList(post: $1, subscriptionInfo: subscriptionInfo, number: self.isDescending ? totalElements - page * numberOfElements - $0 : page * numberOfElements + ($0 + 1)) }
            }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        // tableView의 row 선택 시
        let selectedIndexPath = input.selectedIndexPath
            .map { (uri, $0) }

        // 시리즈 포스트 목록이 없을 때 emptyView
        let embedPostEmptyView = seriesPostList
            .filter { $0.items.isEmpty }
            .map { _ in .projectPostListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // 로딩 뷰
        let activityIndicator = loadSeriesInfoAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            viewDidLayoutSubviews: input.viewDidLayoutSubviews,
            traitCollectionDidChange: input.traitCollectionDidChange,
            seriesInfo: loadSeriesInfoSuccess,
            seriesPostList: seriesPostList,
            isDescending: isDescending,
            embedEmptyViewController: embedPostEmptyView,
            selectedIndexPath: selectedIndexPath,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
