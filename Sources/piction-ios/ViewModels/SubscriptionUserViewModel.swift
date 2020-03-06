//
//  SubscriptionUserViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/28.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ViewModel
final class SubscriptionUserViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let uri: String

    init(dependency: Dependency) {
        (firebaseManager, uri) = dependency
    }

    var page = 0
    var items: [SponsorModel] = []
    var shouldInfiniteScroll = true

    var loadNextTrigger = PublishSubject<Void>()
}

// MARK: - Input & Output
extension SubscriptionUserViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let subscriptionUserList: Driver<[SponsorModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let dismissViewController: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension SubscriptionUserViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, uri) = (self.firebaseManager, self.uri)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("구독자 목록")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // pull to refresh 액션 시
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        // 최초 진입 시, pull to refresh 액션 시
        let initialPage = Driver.merge(initialLoad, refreshControlDidRefresh)
            .do(onNext: { [weak self] _ in
                // 데이터 초기화
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 최초 진입 시, pull to refresh 액션 시, infinite scroll로 다음 페이지 호출
        // 구독자 목록 호출
        let subscriptionUserListAction = Driver.merge(initialPage, loadNext)
            .map { CreatorAPI.projectSponsors(uri: uri, page: self.page + 1, size: 30) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독자 목록 호출 성공 시
        let subscriptionUserListSuccess = subscriptionUserListAction.elements
            .map { try? $0.map(to: PageViewResponse<SponsorModel>.self) }
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList?.pageable?.pageNumber,
                    let totalPages = pageList?.totalPages
                else { return }

                // 페이지 증가
                self.page = self.page + 1

                // 현재 페이지가 전체페이지보다 작을때만 infiniteScroll 동작
                self.shouldInfiniteScroll = pageNumber < totalPages - 1
            })
            .map { $0?.content ?? [] }
            .map { self.items.append(contentsOf: $0) }
            .map { self.items }

        // 구독자 목록 호출 에러 시
        let subscriptionUserListError = subscriptionUserListAction.error
            .map { _ in [SponsorModel]() }

        // 구독자 목록
        let subscriptionUserList = Driver.merge(subscriptionUserListSuccess, subscriptionUserListError)

        // pull to refresh 로딩 및 해제
        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(subscriptionUserList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        // 구독자 목록이 없을 때 emptyView 출력
        let embedEmptyView = subscriptionUserList
            .filter { $0.isEmpty }
            .map { _ in .searchListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        return Output(
            viewWillAppear: viewWillAppear,
            traitCollectionDidChange: input.traitCollectionDidChange,
            subscriptionUserList: subscriptionUserList,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
