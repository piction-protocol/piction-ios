//
//  SubscriptionListViewModel.swift
//  PictionView
//
//  Created by jhseo on 25/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SubscriptionListViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater) = dependency
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
        let subscriptionList: Driver<[ProjectModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let openProjectViewController: Driver<IndexPath>
        let isFetching: Driver<Bool>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let refreshSession: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater) = (self.firebaseManager, self.updater)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("구독")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialPage = Driver.merge(initialLoad, refreshSession, refreshContent, refreshControlDidRefresh)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let subscriptionListAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { SubscriberAPI.projects(page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionListSuccess = subscriptionListAction.elements
            .map { try? $0.map(to: PageViewResponse<ProjectModel>.self) }
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList?.pageable?.pageNumber,
                    let totalPages = pageList?.totalPages
                else { return }
                self.page = self.page + 1
                if pageNumber >= totalPages - 1 {
                    self.shouldInfiniteScroll = false
                }
            })
            .map { $0?.content ?? [] }
            .map { self.items.append(contentsOf: $0) }
            .map { self.items }

        let subscriptionListError = subscriptionListAction.error
            .flatMap { response -> Driver<Void> in
                let errorType = response as? ErrorType
                switch errorType {
                case .unauthorized:
                    return Driver.empty()
                default:
                    return Driver.just(())
                }
            }

        let subscriptionEmptyList = subscriptionListAction.error
            .map { _ in [ProjectModel]() }

        let subscriptionList = Driver.merge(subscriptionListSuccess, subscriptionEmptyList)
        let showErrorPopup = subscriptionListError

        let embedEmptyLoginView = subscriptionListAction.error
            .flatMap { response -> Driver<CustomEmptyViewStyle> in
                let errorType = response as? ErrorType
                switch errorType {
                case .unauthorized:
                    return Driver.just(.defaultLogin)
                default:
                    return Driver.empty()
                }
            }
            .do(onNext: { [weak self] _ in
                self?.shouldInfiniteScroll = false
            })

        let embedEmptyView = subscriptionListSuccess
            .filter { $0.isEmpty }
            .map { _ in .subscriptionListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)
            .do(onNext: { [weak self] _ in
                self?.shouldInfiniteScroll = false
            })

        let embedEmptyViewController = Driver.merge(embedEmptyView, embedEmptyLoginView)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(subscriptionList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let showActivityIndicator = Driver.merge(initialPage, loadRetry)
            .map { true }

        let hideActivityIndicator = subscriptionList
            .map { _ in false }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            subscriptionList: subscriptionList,
            embedEmptyViewController: embedEmptyViewController,
            openProjectViewController: input.selectedIndexPath,
            isFetching: refreshAction.isExecuting,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            refreshSession: refreshSession
        )
    }
}
