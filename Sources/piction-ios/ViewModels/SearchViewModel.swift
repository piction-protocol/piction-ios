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

// MARK: - SearchSection
enum SearchSection {
    case project(item: ProjectModel)
    case tag(item: TagModel)
}

// MARK: - ViewModel
final class SearchViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol

    init(dependency: Dependency) {
        firebaseManager = dependency
    }

    var page = 0
    var sections: [SearchSection] = []
    var shouldInfiniteScroll = true

    var loadNextTrigger = PublishSubject<Void>()

    var menu = BehaviorSubject<Int>(value: 0)
    var searchText = BehaviorSubject<String>(value: "")
}

// MARK: - Input & Output
extension SearchViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let searchText: Driver<String>
        let segmentedControlDidChange: Driver<Int>
        let selectedIndexPath: Driver<IndexPath>
        let contentOffset: Driver<CGPoint>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let setPlaceHolder: Driver<String>
        let menuChanged: Driver<Int>
        let searchList: Driver<SectionType<SearchSection>>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let dismissViewController: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension SearchViewModel {
    func build(input: Input) -> Output {
        let firebaseManager = self.firebaseManager

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("검색")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 화면이 보여지기 전에 searchBar의 placeHolder 설정
        let setPlaceHolder = input.viewWillAppear
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .map { $0 == 0 ? LocalizationKey.hint_project_search.localized() : LocalizationKey.hint_tag_search.localized() }

        // segmentedControl의 값이 변경 될 때
        let menuChange = input.segmentedControlDidChange
            .do(onNext: { [weak self] menu in
                // 데이터 초기화
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
                self?.menu.onNext(menu)
            })
            .map { _ in Void() }

        // 검색 입력 시
        let inputSearchText = input.searchText
            .do(onNext: { [weak self] searchText in
                // 데이터 초기화
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
                self?.searchText.onNext(searchText)
            })
            .map { _ in Void() }

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 검색 입력이 아무것도 없을 경우
        let searchTextIsEmpty = self.searchText
            .asDriver(onErrorDriveWith: .empty())
            .filter { $0 == "" }
            .map { _ in SectionType<SearchSection>.Section(title: "project", items: []) }

        // 최초 진입 시, 검색 입력이 아무것도 없을 경우, segmentControl 값이 변경될 때
        // guideEmptyView 출력
        let searchGuideEmptyView = Driver.merge(initialLoad, inputSearchText, menuChange)
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == "" }
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .do(onNext: { [weak self] _ in
                // 데이터 초기화
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = false
            })
            .map { $0 == 0 ? .searchProjectGuide : .searchTagGuide }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // 검색어 입력 시, infinite scroll로 다음 페이지 호출 시, segmentControl 값이 변경될 때
        // 프로젝트 검색 호출
        let searchProjectAction = Driver.merge(inputSearchText, loadNext, menuChange)
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == 0 }
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .map { SearchAPI.projects(name: $0, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMapLatest(Action.makeDriver)

        // 프로젝트 검색 호출 성공 시
        let searchProjectActionSuccess = searchProjectAction.elements
            .map { try? $0.map(to: PageViewResponse<ProjectModel>.self) }
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList?.pageable?.pageNumber,
                    let totalPages = pageList?.totalPages
                else { return }

                // 페이지 증가
                self.page = self.page + 1

                // 현재 페이지가 전체페이지보다 작을때만 infiniteScroll 동작
                self.shouldInfiniteScroll = pageNumber < totalPages - 1
            })
            .map { ($0?.content ?? []).map { SearchSection.project(item: $0) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<SearchSection>.Section(title: "project", items: self.sections) }

        // 검색어 입력 시, infinite scroll로 다음 페이지 호출 시, segmentControl 값이 변경될 때
        // 태그 검색 호출
        let searchTagAction = Driver.merge(inputSearchText, loadNext, menuChange)
            .withLatestFrom(self.menu.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == 1 }
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .map { SearchAPI.tag(tag: $0, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMapLatest(Action.makeDriver)

        // 태그 검색 호출 성공 시
        let searchTagActionSuccess = searchTagAction.elements
            .map { try? $0.map(to: PageViewResponse<TagModel>.self) }
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList?.pageable?.pageNumber,
                    let totalPages = pageList?.totalPages
                else { return }

                // 페이지 증가
                self.page = self.page + 1

                // 현재 페이지가 전체페이지보다 작을때만 infiniteScroll 동작
                self.shouldInfiniteScroll = pageNumber < totalPages - 1
            })
            .map { ($0?.content ?? []).map { SearchSection.tag(item: $0) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<SearchSection>.Section(title: "tag", items: self.sections) }

        // 프로젝트 검색 호출 성공 시, 태그 검색 호출 성공 시, 아무것도 입력하지 않았을 때
        // 검색 목록 출력
        let searchList = Driver.merge(searchProjectActionSuccess, searchTagActionSuccess, searchTextIsEmpty)

        // 검색 목록에 아무것도 없을 때 emptyView 출력
        let embedEmptyView = searchList
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .withLatestFrom(searchList)
            .filter { $0.items.isEmpty }
            .map { _ in .searchListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // guideEmptyView 출력 시, emptyView 출력 시
        let embedEmptyViewController = Driver.merge(searchGuideEmptyView, embedEmptyView)

        // 검색 결과가 아무것도 없을 때 스크롤 하면 검색화면 닫음
        let dismissViewController = input.contentOffset
            .withLatestFrom(searchList)
            .filter { $0.items.isEmpty }
            .map { _ in Void() }

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            traitCollectionDidChange: input.traitCollectionDidChange,
            setPlaceHolder: setPlaceHolder,
            menuChanged: input.segmentedControlDidChange,
            searchList: searchList,
            selectedIndexPath: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyViewController,
            dismissViewController: dismissViewController
        )
    }
}
