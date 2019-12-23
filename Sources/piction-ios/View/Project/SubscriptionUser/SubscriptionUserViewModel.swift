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
    var items: [SubscriptionUserModel] = []
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
        let subscriptionUserList: Driver<[SubscriptionUserModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let uri = self.uri

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, input.refreshControlDidRefresh)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 0
                self.items = []
                self.shouldInfiniteScroll = true
                return Driver.just(())
            }

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                return Driver.just(())
            }

        let subscriptionUserListAction = Driver.merge(initialLoad, loadNext)
           .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
            guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(MyAPI.projectSubscriptions(uri: uri, page: self.page + 1, size: 30))
                return Action.makeDriver(response)
           }

        let subscriptionUserListSuccess = subscriptionUserListAction.elements
           .flatMap { [weak self] response -> Driver<[SubscriptionUserModel]> in
               guard let `self` = self else { return Driver.empty() }
               guard let pageList = try? response.map(to: PageViewResponse<SubscriptionUserModel>.self) else {
                   return Driver.empty()
               }
               self.page = self.page + 1
               if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                   self.shouldInfiniteScroll = false
               }
               self.items.append(contentsOf: pageList.content ?? [])
               return Driver.just(self.items)
           }

        let subscriptionUserListError = subscriptionUserListAction.error
            .flatMap { _ in Driver.just([SubscriptionUserModel.from([:])!]) }

        let subscriptionUserList = Driver.merge(subscriptionUserListSuccess, subscriptionUserListError)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(subscriptionUserList)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let embedEmptyView = subscriptionUserList
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.searchListEmpty)
                }
                return Driver.empty()
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            subscriptionUserList: subscriptionUserList,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
