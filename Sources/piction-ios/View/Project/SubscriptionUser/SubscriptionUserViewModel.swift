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

final class SubscriptionUserViewModel: ViewModel {

    var page = 0
    var items: [SubscriberModel] = []
    var shouldInfiniteScroll = true

    var loadTrigger = PublishSubject<Void>()

    let uri: String

    init(uri: String) {
        self.uri = uri
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let subscriptionUserList: Driver<[SubscriberModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let uri = self.uri

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, input.refreshControlDidRefresh)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let subscriptionUserListAction = Driver.merge(initialLoad, loadNext)
            .map { MyAPI.projectSubscriptions(uri: uri, page: self.page + 1, size: 30) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionUserListSuccess = subscriptionUserListAction.elements
            .map { try? $0.map(to: PageViewResponse<SubscriberModel>.self) }
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

        let subscriptionUserListError = subscriptionUserListAction.error
            .map { _ in [SubscriberModel]() }

        let subscriptionUserList = Driver.merge(subscriptionUserListSuccess, subscriptionUserListError)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(subscriptionUserList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let embedEmptyView = subscriptionUserList
            .filter { $0.isEmpty }
            .map { _ in .searchListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        return Output(
            viewWillAppear: input.viewWillAppear,
            subscriptionUserList: subscriptionUserList,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
