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

// MARK: - ViewModel
final class TaggingProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager, tag) = dependency
    }

    var page = 0
    var tag = ""
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()
}

// MARK: - Input & Output
extension TaggingProjectViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let navigationTitle: Driver<String>
        let taggingProjectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension TaggingProjectViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, tag) = (self.firebaseManager, self.tag)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("태그 상세")
            })

        // 화면이 보여지기 전에 네비게이션 타이틀 전달
        let navigationTitle = input.viewWillAppear
            .map { tag }

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // pull to refresh 액션 시
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        // 최초 진입 시, pull to refresh 액션 시
        let initialPage = Driver.merge(initialLoad, refreshControlDidRefresh)
            .do(onNext: { [weak self] in
                // 데이터 초기화
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 최초 진입 시, pull to refresh 액션 시, 새로고침 시, 다음 페이지 호출 시
        // taggingProject 호출
        let taggingProjectListAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { SearchAPI.taggingProjects(tag: tag, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // taggingProject 호출 성공 시
        let taggingProjectListSuccess = taggingProjectListAction.elements
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
            .map { self.items.append(contentsOf: $0?.content ?? []) }
            .map { self.items }

        // taggingProject 호출 에러 시
        let taggingProjectError = taggingProjectListAction.error
            .map { _ in Void() }

        // taggingProject 호출 empty list 전달
        let taggingProjectEmptyList = taggingProjectListAction.error
            .map { _ in [ProjectModel]() }

        // taggingProject list 전달
        let taggingProjectList = Driver.merge(taggingProjectListSuccess, taggingProjectEmptyList)

        // taggingProject 호출 에러 시 에러 팝업 출력
        let showErrorPopup = taggingProjectError

        // pull to refresh 로딩 및 해제
        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(taggingProjectList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        // taggingProject 호출 성공하였지만 데이터가 없는 경우 emptyView 출력
        let embedEmptyView = taggingProjectListSuccess
            .filter { $0.isEmpty }
            .map { _ in .searchListEmpty}
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // 로딩 뷰
        let activityIndicator = taggingProjectListAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            traitCollectionDidChange: input.traitCollectionDidChange,
            navigationTitle: navigationTitle,
            taggingProjectList: taggingProjectList,
            selectedIndexPath: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            isFetching: refreshAction.isExecuting,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}

