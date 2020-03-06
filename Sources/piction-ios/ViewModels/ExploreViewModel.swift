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

// MARK: - ViewModel
final class ExploreViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater) = dependency
    }
}

// MARK: - Input & Output
extension ExploreViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let refreshControlDidRefresh: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let embedCategoryListViewController: Driver<Void>
        let projectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension ExploreViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater) = (self.firebaseManager, self.updater)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("탐색")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시 CategoryListViewController embed
           let embedCategoryListViewController = initialLoad

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // pull to refresh 액션 시
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, pull to refresh 액션 시
        let initialPage = Driver.merge(initialLoad, refreshSession, refreshContent, refreshControlDidRefresh)
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.items = []
                self?.shouldInfiniteScroll = true
            })

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, pull to refresh 액션 시,  infinite scroll로 다음 페이지 호출 시, 새로고침 필요 시
        // 프로젝트 목록 호출
        let projectListAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { ProjectAPI.all(page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 목록 호출 성공 시
        let projectListSuccess = projectListAction.elements
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
            .map { $0?.content ?? [] }
            .map { self.items.append(contentsOf: $0) }
            .map { self.items }

        // 프로젝트 목록
        let projectList = projectListSuccess

        // 프로젝트 목록 호출 에러 시
        let projectListError = projectListAction.error
            .map { _ in Void() }

        // 에러 팝업 출력
        let showErrorPopup = projectListError

        // pull to refresh 로딩 및 해제
        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(projectList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        // 최초 진입 시, 새로고침 필요 시
        // 로딩 뷰 출력
        let showActivityIndicator = Driver.merge(initialPage, loadRetry)
            .map { true }

        // 프로젝트 정보를 불러오면
        // 로딩 뷰 해제
        let hideActivityIndicator = projectList
            .map { _ in false }

        // 로딩 뷰
        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        return Output(
            viewWillAppear: viewWillAppear,
            viewDidAppear: input.viewDidAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            traitCollectionDidChange: input.traitCollectionDidChange,
            embedCategoryListViewController: embedCategoryListViewController,
            projectList: projectList,
            selectedIndexPath: input.selectedIndexPath,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }
}
