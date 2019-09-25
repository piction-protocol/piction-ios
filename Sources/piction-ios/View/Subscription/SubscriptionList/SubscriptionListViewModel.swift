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
import RxPictionSDK

final class SubscriptionListViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let subscriptionList: Driver<[ProjectModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let openProjectViewController: Driver<ProjectModel>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, refreshSession, refreshContent)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 1
                self.items = []
                self.shouldInfiniteScroll = true
                return Driver.just(())
            }

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                self.page = self.page + 1
                return Driver.just(())
            }

        let subscriptionListAction = Driver.merge(initialLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(MyAPI.subscription(page: self.page, size: 10))
                return Action.makeDriver(response)
            }

        let subscriptionListSuccess = subscriptionListAction.elements
            .flatMap { [weak self] response -> Driver<[ProjectModel]> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                self.items.append(contentsOf: pageList.content ?? [])
                return Driver.just(self.items)
            }

        let subscriptionListError = subscriptionListAction.error
            .flatMap { _ -> Driver<[ProjectModel]> in
                return Driver.just([])
            }

        let embedEmptyLoginView = subscriptionListAction.error
            .flatMap { [weak self] response -> Driver<CustomEmptyViewStyle> in
                self?.shouldInfiniteScroll = false
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                switch errorMsg {
                case .unauthorized:
                    return Driver.just(.defaultLogin)
                default:
                    return Driver.empty()
                }
            }

        let embedEmptyView = subscriptionListSuccess
            .flatMap { [weak self] items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    self?.shouldInfiniteScroll = false
                    return Driver.just(.subscriptionListEmpty)
                }
                return Driver.empty()
            }

        let embedEmptyViewController = Driver.merge(embedEmptyView, embedEmptyLoginView)

        let openProjectViewController = input.selectedIndexPath
            .flatMap { [weak self] indexPath -> Driver<ProjectModel> in
                guard let `self` = self else { return Driver.empty() }
                guard self.items.count > indexPath.row else { return Driver.empty() }
                return Driver.just(self.items[indexPath.row])
            }

        let subscriptionList = Driver.merge(subscriptionListSuccess, subscriptionListError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            subscriptionList: subscriptionList,
            embedEmptyViewController: embedEmptyViewController,
            openProjectViewController: openProjectViewController
        )
    }
}
