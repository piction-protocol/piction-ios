//
//  ExploreViewModel.swift
//  PictionView
//
//  Created by jhseo on 25/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ExploreViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

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
        let projectList: Driver<[ProjectModel]>
        let openProjectViewController: Driver<IndexPath>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialLoad = Driver.merge(viewWillAppear, refreshSession, refreshContent, refreshControlDidRefresh)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let projectListAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .map { ProjectsAPI.all(page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let projectListSuccess = projectListAction.elements
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

        let projectListError = projectListAction.error
            .map { _ in Void() }

        let projectList = projectListSuccess

        let showErrorPopup = projectListError

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(projectList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let showActivityIndicator = Driver.merge(initialLoad, loadRetry)
            .map { true }

        let hideActivityIndicator = projectList
            .map { _ in false }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            projectList: projectList,
            openProjectViewController: input.selectedIndexPath,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }
}
