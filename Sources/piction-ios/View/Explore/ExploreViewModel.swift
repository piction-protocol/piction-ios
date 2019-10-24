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

    var loadTrigger = PublishSubject<Void>()

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
        let openProjectViewController: Driver<ProjectModel>
        let isFetching: Driver<Bool>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialLoad = Driver.merge(viewWillAppear, refreshSession, refreshContent, refreshControlDidRefresh)
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

        let projectListAction = Driver.merge(initialLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.all(page: self.page, size: 20))
                return Action.makeDriver(response)
            }

        let projectListSuccess = projectListAction.elements
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

        let projectListError = projectListAction.error
            .flatMap { _ -> Driver<[ProjectModel]> in
                return Driver.just([])
            }

        let openProjectViewController = input.selectedIndexPath
            .flatMap { [weak self] indexPath -> Driver<ProjectModel> in
                guard let `self` = self else { return Driver.empty() }
                guard self.items.count > indexPath.row else { return Driver.empty() }
                return Driver.just(self.items[indexPath.row])
            }

        let projectList = Driver.merge(projectListSuccess, projectListError)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(projectList)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            projectList: projectList,
            openProjectViewController: openProjectViewController,
            isFetching: refreshAction.isExecuting
        )
    }
}
