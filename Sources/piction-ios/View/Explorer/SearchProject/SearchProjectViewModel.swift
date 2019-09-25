//
//  SearchProjectViewModel.swift
//  PictionView
//
//  Created by jhseo on 09/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK
import RxPictionSDK

final class SearchProjectViewModel: ViewModel {

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadTrigger = PublishSubject<Void>()

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let searchText: Driver<String>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectList: Driver<[ProjectModel]>
        let openProjectViewController: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear

        let openProjectViewController = input.selectedIndexPath

        let inputSearchText = input.searchText
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

        let searchAction = Driver.merge(inputSearchText, loadNext)
            .withLatestFrom(input.searchText)
            .filter { $0 != "" }
            .flatMap { [weak self] searchText ->
                Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SearchAPI.project(name: searchText, page: self?.page ?? 0, size: 10))
                return Action.makeDriver(response)
            }

        let searchTextIsEmpty = input.searchText
            .filter { $0 == "" }
            .flatMap { _ -> Driver<[ProjectModel]> in
                return Driver.just([])
            }

        let searchProjectGuideEmptyView = input.searchText
            .filter { $0 == "" }
            .flatMap { [weak self] _ -> Driver<CustomEmptyViewStyle> in
                self?.shouldInfiniteScroll = false
                return Driver.just(.searchProjectGuide)
            }

        let searchActionSuccess = searchAction.elements
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

        let projectList = Driver.merge(searchActionSuccess, searchTextIsEmpty)

        let embedEmptyView = projectList
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.searchProjectListEmpty)
                }
                return Driver.empty()
            }

        let embedEmptyViewController = Driver.merge(searchProjectGuideEmptyView, embedEmptyView)

        return Output(
            viewWillAppear: viewWillAppear,
            projectList: projectList,
            openProjectViewController: openProjectViewController,
            embedEmptyViewController: embedEmptyViewController
        )
    }
}
