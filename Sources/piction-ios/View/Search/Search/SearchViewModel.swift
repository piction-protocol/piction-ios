//
//  SearchViewModel.swift
//  PictionView
//
//  Created by jhseo on 09/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

enum SearchSection {
    case project(item: ProjectModel)
    case tag(item: TagModel)
}

final class SearchViewModel: ViewModel {

    var page = 0
    var sections: [SearchSection] = []
    var shouldInfiniteScroll = true

    var loadNextTrigger = PublishSubject<Void>()

    var menu = BehaviorSubject<Int>(value: 0)
    var searchText = BehaviorSubject<String>(value: "")

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let searchText: Driver<String>
        let segmentedControlDidChange: Driver<Int>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let setPlaceHolder: Driver<Int>
        let menuChanged: Driver<Int>
        let searchList: Driver<SectionType<SearchSection>>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let setPlaceHolder = input.viewWillAppear
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .flatMap { menu -> Driver<Int> in
                return Driver.just(menu)
            }

        let menuChange = input.segmentedControlDidChange
            .flatMap { [weak self] menu -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 0
                self.sections = []
                self.shouldInfiniteScroll = true
                self.menu.onNext(menu)
                return Driver.just(())
            }

        let inputSearchText = input.searchText
            .flatMap { [weak self] searchText -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 0
                self.sections = []
                self.shouldInfiniteScroll = true
                self.searchText.onNext(searchText)
                return Driver.just(())
            }

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                return Driver.just(())
            }

        let searchTextIsEmpty = self.searchText.asDriver(onErrorDriveWith: .empty())
            .filter { $0 == "" }
            .flatMap { _ -> Driver<SectionType<SearchSection>> in
                return Driver.just(SectionType<SearchSection>.Section(title: "project", items: []))
            }

        let searchGuideEmptyView = Driver.merge(viewWillAppear, inputSearchText, menuChange)
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == "" }
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .flatMap { [weak self] menu -> Driver<CustomEmptyViewStyle> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 0
                self.sections = []
                self.shouldInfiniteScroll = false
                if menu == 0 {
                    return Driver.just(.searchProjectGuide)
                } else {
                    return Driver.just(.searchTagGuide)
                }
            }

        let searchProjectAction = Driver.merge(inputSearchText, loadNext, menuChange)
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == 0 }
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .flatMapLatest { [weak self] searchText ->
                Driver<Action<ResponseData>> in
                print(searchText)
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SearchAPI.project(name: searchText, page: self.page + 1, size: 20))
                return Action.makeDriver(response)
            }

        let searchProjectActionSuccess = searchProjectAction.elements
            .flatMap { [weak self] response -> Driver<SectionType<SearchSection>> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                self.page = self.page + 1
                if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                let projects: [SearchSection] = (pageList.content ?? []).map { .project(item: $0) }
                self.sections.append(contentsOf: projects)

                return Driver.just(SectionType<SearchSection>.Section(title: "project", items: self.sections))
            }

        let searchTagAction = Driver.merge(inputSearchText, loadNext, menuChange)
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == 1 }
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .flatMapLatest { [weak self] searchText ->
                Driver<Action<ResponseData>> in
                print(searchText)
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SearchAPI.tag(tag: searchText, page: self.page + 1, size: 20))
                return Action.makeDriver(response)
            }

        let searchTagActionSuccess = searchTagAction.elements
            .flatMap { [weak self] response -> Driver<SectionType<SearchSection>> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<TagModel>.self) else {
                    return Driver.empty()
                }
                if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                self.page = self.page + 1
                let tags: [SearchSection] = (pageList.content ?? []).map { .tag(item: $0) }
                self.sections.append(contentsOf: tags)

                return Driver.just(SectionType<SearchSection>.Section(title: "tag", items: self.sections))
            }

        let searchList = Driver.merge(searchProjectActionSuccess, searchTagActionSuccess, searchTextIsEmpty)

        let embedEmptyView = searchList
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .withLatestFrom(searchList)
            .flatMap { [weak self] sections -> Driver<CustomEmptyViewStyle> in
                if sections.items.count == 0 {
                    return Driver.just(.searchListEmpty)
                }
                return Driver.empty()
            }

        let embedEmptyViewController = Driver.merge(searchGuideEmptyView, embedEmptyView)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            setPlaceHolder: setPlaceHolder,
            menuChanged: input.segmentedControlDidChange,
            searchList: searchList,
            selectedIndexPath: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyViewController
        )
    }
}
