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

    var loadTrigger = PublishSubject<Void>()

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
        let openProjectViewController: Driver<ProjectModel>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let navigationTitle = input.viewWillAppear
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.tag ?? "")
            }

        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialLoad = Driver.merge(viewWillAppear, refreshControlDidRefresh)
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

        let tagResultProjectListAction = Driver.merge(initialLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.all(page: self.page, size: 20, tagName: self.tag))
                return Action.makeDriver(response)
            }

        let tagResultProjectListSuccess = tagResultProjectListAction.elements
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

        let tagResultProjectListError = tagResultProjectListAction.error
            .flatMap { _ -> Driver<[ProjectModel]> in
                return Driver.just([])
            }

        let openProjectViewController = input.selectedIndexPath
            .flatMap { [weak self] indexPath -> Driver<ProjectModel> in
                guard let `self` = self else { return Driver.empty() }
                guard self.items.count > indexPath.row else { return Driver.empty() }
                return Driver.just(self.items[indexPath.row])
            }

        let tagResultProjectList = Driver.merge(tagResultProjectListSuccess, tagResultProjectListError)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(tagResultProjectList)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let embedEmptyView = tagResultProjectListSuccess
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.searchListEmpty)
                }
                return Driver.empty()
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            navigationTitle: navigationTitle,
            tagResultProjectList: tagResultProjectList,
            openProjectViewController: openProjectViewController,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting
        )
    }
}

