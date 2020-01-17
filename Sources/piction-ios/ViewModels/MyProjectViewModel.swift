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

final class MyProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    var projectList: [ProjectModel] = []
    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

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
        let openProjectViewController: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let updater = self.updater

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

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

        let activityIndicator = myProjectAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            projectList: myProjectSuccess,
            openCreateProjectViewController: openCreateProjectViewController,
            openProjectViewController: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
