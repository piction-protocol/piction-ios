//
//  SponsorshipHistoryViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 20/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SponsorshipHistoryViewModel: ViewModel {

    var page = 0
    var items: [SponsorshipModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let sponsorshipList: Driver<[SponsorshipModel]>
        let isFetching: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, input.refreshControlDidRefresh)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 0
                self.items = []
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

        let sponsorshipListAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SponsorshipsAPI.get(page: self.page + 1, size: 20))
                return Action.makeDriver(response)
        }

        let sponsorshipListSuccess = sponsorshipListAction.elements
            .flatMap { [weak self] response -> Driver<[SponsorshipModel]> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<SponsorshipModel>.self) else {
                    return Driver.empty()
                }
                self.page = self.page + 1
                if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                self.items.append(contentsOf: pageList.content ?? [])
                return Driver.just(self.items)
            }

        let sponsorshipListError = sponsorshipListAction.error
            .flatMap { _ in Driver.just(()) }

        let showErrorPopup = sponsorshipListError

        let embedEmptyView = sponsorshipListSuccess
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.sponsorshipListEmpty)
                }
                return Driver.empty()
            }

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(sponsorshipListSuccess)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let showActivityIndicator = initialLoad
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = sponsorshipListSuccess
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        return Output(
            viewWillAppear: input.viewWillAppear,
            sponsorshipList: sponsorshipListSuccess,
            isFetching: refreshAction.isExecuting,
            embedEmptyViewController: embedEmptyView,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
