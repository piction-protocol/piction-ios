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

        let myProjectAction = Driver.merge(initialLoad, refreshContent, loadRetry)
            .map { CreatorAPI.projects }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let myProjectSuccess = myProjectAction.elements
            .map { try? $0.map(to: [ProjectModel].self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] projects in
                self?.projectList = projects
            })

        let myProjectError = myProjectAction.error
            .map { _ in Void() }

        let openCreateProject = input.createProjectBtnDidTap
            .map { _ in IndexPath?(nil) }

        let openEditProject = input.contextualAction
            .flatMap(Driver<IndexPath?>.from)

        let openCreateProjectViewController = Driver.merge(openCreateProject, openEditProject)

        let showErrorPopup = myProjectError

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
