//
//  TagResultProjectViewModel.swift
//  piction-ios
//
//  Created by jhseo on 16/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class TagResultProjectViewModel: ViewModel {

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
        let tagResultProjectList: Driver<[ProjectModel]>
        let openProjectViewController: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let tag = self.tag

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let navigationTitle = viewWillAppear
            .map { tag }

        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialLoad = Driver.merge(viewWillAppear, refreshControlDidRefresh)
            .do(onNext: { [weak self] in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let tagResultProjectListAction = Driver.merge(initialLoad, loadNext, loadRetry)
            .map { SearchAPI.taggingProjects(tag: tag, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let tagResultProjectListSuccess = tagResultProjectListAction.elements
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

        let tagResultProjectError = tagResultProjectListAction.error
            .map { _ in Void() }

        let tagResultProjectEmptyList = tagResultProjectListAction.error
            .map { _ in [ProjectModel]() }

        let tagResultProjectList = Driver.merge(tagResultProjectListSuccess, tagResultProjectEmptyList)

        let showErrorPopup = tagResultProjectError

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(tagResultProjectList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let embedEmptyView = tagResultProjectListSuccess
            .filter { $0.isEmpty }
            .map { _ in .searchListEmpty}
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let activityIndicator = tagResultProjectListAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            navigationTitle: navigationTitle,
            tagResultProjectList: tagResultProjectList,
            openProjectViewController: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}

