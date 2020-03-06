//
//  CategorizedProjectViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/08.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ViewModel
final class CategorizedProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        Int
    )

    let firebaseManager: FirebaseManagerProtocol
    let updater: UpdaterProtocol
    let categoryId: Int

    var page = 0
    var items: [ProjectModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, categoryId) = dependency
    }
}

// MARK: - Input & Output
extension CategorizedProjectViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let viewDidLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let viewDidLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let categoryInfo: Driver<CategoryModel>
        let projectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension CategorizedProjectViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, categoryId) = (self.firebaseManager, self.updater, self.categoryId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("카테고리상세_\(categoryId)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        let initialPage = Driver.merge(initialLoad, refreshSession, refreshContent)
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

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 새로고침 필요 시
        // 카테고리 정보 호출
        let categoryInfoAction = Driver.merge(initialPage, loadRetry)
            .map { CategoryAPI.get(id: self.categoryId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 카테고리 정보 호출 성공 시
        let categoryInfoSuccess = categoryInfoAction.elements
            .map { try? $0.map(to: CategoryModel.self) }
            .flatMap(Driver.from)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, infinite scroll로 다음 페이지 호출 시, 새로고침 필요 시
        // 프로젝트 목록 호출
        let projectListAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { CategoryAPI.categorizedProjects(id: self.categoryId, page: self.page + 1, size: 20) }
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

        // 프로젝트 목록 호출 에러 시
        let projectListError = projectListAction.error
            .map { _ in Void() }

        // 프로젝트 목록
        let projectList = projectListSuccess

        // 에러 팝업 출력
        let showErrorPopup = projectListError

        // 로딩 뷰
        let activityIndicator = categoryInfoAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            viewDidLayoutSubviews: input.viewDidLayoutSubviews,
            traitCollectionDidChange: input.traitCollectionDidChange,
            categoryInfo: categoryInfoSuccess,
            projectList: projectList,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }
}
