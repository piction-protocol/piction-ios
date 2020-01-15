//
//  CategorizedProjectViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/08.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CategorizedProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        Int
    )

    let updater: UpdaterProtocol
    let categoryId: Int

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, categoryId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let categoryInfo: Driver<CategoryModel>
        let projectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, refreshSession, refreshContent)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let categoryInfoAction = Driver.merge(initialLoad, loadRetry)
            .map { CategoryAPI.get(id: self.categoryId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let categoryInfoSuccess = categoryInfoAction.elements
            .map { try? $0.map(to: CategoryModel.self) }
            .flatMap(Driver.from)

        let projectListAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .map { CategoryAPI.categorizedProjects(id: self.categoryId, page: self.page + 1, size: 20) }
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

        let activityIndicator = categoryInfoAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            categoryInfo: categoryInfoSuccess,
            projectList: projectList,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }
}
