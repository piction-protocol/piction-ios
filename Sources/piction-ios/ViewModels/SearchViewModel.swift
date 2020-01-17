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
        let contentOffset: Driver<CGPoint>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let setPlaceHolder: Driver<Int>
        let menuChanged: Driver<Int>
        let searchList: Driver<SectionType<SearchSection>>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let setPlaceHolder = input.viewWillAppear
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))

        let menuChange = input.segmentedControlDidChange
            .do(onNext: { [weak self] menu in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
                self?.menu.onNext(menu)
            })
            .map { _ in Void() }

        let inputSearchText = input.searchText
            .do(onNext: { [weak self] searchText in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
                self?.searchText.onNext(searchText)
            })
            .map { _ in Void() }

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let searchTextIsEmpty = self.searchText.asDriver(onErrorDriveWith: .empty())
            .filter { $0 == "" }
            .map { _ in SectionType<SearchSection>.Section(title: "project", items: []) }

        let searchGuideEmptyView = Driver.merge(initialLoad, inputSearchText, menuChange)
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == "" }
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = false
            })
            .map { $0 == 0 ? .searchProjectGuide : .searchTagGuide }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let searchProjectAction = Driver.merge(inputSearchText, loadNext, menuChange)
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == 0 }
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .map { SearchAPI.projects(name: $0, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMapLatest(Action.makeDriver)

        let searchProjectActionSuccess = searchProjectAction.elements
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
            .map { ($0?.content ?? []).map { SearchSection.project(item: $0) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<SearchSection>.Section(title: "project", items: self.sections) }

        let searchTagAction = Driver.merge(inputSearchText, loadNext, menuChange)
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == 1 }
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .map { SearchAPI.tag(tag: $0, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMapLatest(Action.makeDriver)

        let searchTagActionSuccess = searchTagAction.elements
            .map { try? $0.map(to: PageViewResponse<TagModel>.self) }
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
            .map { ($0?.content ?? []).map { SearchSection.tag(item: $0) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<SearchSection>.Section(title: "tag", items: self.sections) }

        let searchList = Driver.merge(searchProjectActionSuccess, searchTagActionSuccess, searchTextIsEmpty)

        let embedEmptyView = searchList
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .withLatestFrom(searchList)
            .filter { $0.items.isEmpty }
            .map { _ in .searchListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let embedEmptyViewController = Driver.merge(searchGuideEmptyView, embedEmptyView)

        let dismissViewController = input.contentOffset
            .withLatestFrom(searchList)
            .filter { $0.items.isEmpty }
            .map { _ in Void() }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            setPlaceHolder: setPlaceHolder,
            menuChanged: input.segmentedControlDidChange,
            searchList: searchList,
            selectedIndexPath: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyViewController,
            dismissViewController: dismissViewController
        )
    }
}
