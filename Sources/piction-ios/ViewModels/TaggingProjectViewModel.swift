//
//  TaggingProjectViewModel.swift
//  piction-ios
//
//  Created by jhseo on 16/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class TaggingProjectViewModel: ViewModel {

    var page = 0
    var tag = ""
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(tag: String) {
        self.tag = tag
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
        let navigationTitle: Driver<String>
        let taggingProjectList: Driver<[ProjectModel]>
        let openProjectViewController: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let tag = self.tag

        let navigationTitle = input.viewWillAppear
            .map { tag }

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialPage = Driver.merge(initialLoad, refreshControlDidRefresh)
            .do(onNext: { [weak self] in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let taggingProjectListAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { SearchAPI.taggingProjects(tag: tag, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let taggingProjectListSuccess = taggingProjectListAction.elements
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
            .map { self.items.append(contentsOf: $0?.content ?? []) }
            .map { self.items }

        let taggingProjectError = taggingProjectListAction.error
            .map { _ in Void() }

        let taggingProjectEmptyList = taggingProjectListAction.error
            .map { _ in [ProjectModel]() }

        let taggingProjectList = Driver.merge(taggingProjectListSuccess, taggingProjectEmptyList)

        let showErrorPopup = taggingProjectError

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(taggingProjectList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let embedEmptyView = taggingProjectListSuccess
            .filter { $0.isEmpty }
            .map { _ in .searchListEmpty}
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let activityIndicator = taggingProjectListAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            navigationTitle: navigationTitle,
            taggingProjectList: taggingProjectList,
            openProjectViewController: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}

