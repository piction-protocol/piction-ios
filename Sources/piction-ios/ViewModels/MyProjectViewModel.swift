//
//  MyProjectViewModel.swift
//  PictionView
//
//  Created by jhseo on 12/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ViewModel
final class MyProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol

    var projectList: [ProjectModel] = []
    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater) = dependency
    }
}

// MARK: - Input & Output
extension MyProjectViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let createProjectBtnDidTap: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let contextualAction: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let projectList: Driver<[ProjectModel]>
        let openCreateProjectViewController: Driver<IndexPath?>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension MyProjectViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater) = (self.firebaseManager, self.updater)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("마이페이지_나의프로젝트")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 컨텐츠의 내용 갱신 필요 시, 새로고침 필요 시
        // 내 프로젝트 목록 호출
        let myProjectAction = Driver.merge(initialLoad, refreshContent, loadRetry)
            .map { CreatorAPI.projects }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 내 프로젝트 목록 호출 성공 시
        let myProjectSuccess = myProjectAction.elements
            .map { try? $0.map(to: [ProjectModel].self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] projects in
                self?.projectList = projects
            })

        // 내 프로젝트 목록 호출 에러 시
        let myProjectError = myProjectAction.error
            .map { _ in Void() }

        // 생성 버튼 눌렀을 때 (에디터 기능 지원 안함)
        let openCreateProject = input.createProjectBtnDidTap
            .map { _ in IndexPath?(nil) }

        // swipe로 수정 눌렀을 때 (에디터 기능 지원 안함)
        let openEditProject = input.contextualAction
            .flatMap(Driver<IndexPath?>.from)

        // 생성 버튼 눌렀을 때, 수정 눌렀을 때 (에디터 기능 지원 안함)
        // CreatorProject 화면으로 이동
        let openCreateProjectViewController = Driver.merge(openCreateProject, openEditProject)

        // 에러 팝업 출력
        let showErrorPopup = myProjectError

        // 프로젝트 목록이 없을 때 emptyView 출력
        let embedEmptyView = myProjectSuccess
            .filter { $0.isEmpty }
            .map { _ in .myProjectListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // 로딩 뷰
        let activityIndicator = myProjectAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            projectList: myProjectSuccess,
            openCreateProjectViewController: openCreateProjectViewController,
            selectedIndexPath: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
