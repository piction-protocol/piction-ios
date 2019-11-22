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

final class MyProjectViewModel: ViewModel {

    var projectList: [ProjectModel] = []
    var loadRetryTrigger = PublishSubject<Void>()

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let createProjectBtnDidTap: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectList: Driver<[ProjectModel]>
        let openCreateProjectViewController: Driver<Void>
        let openProjectViewController: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let myProjectAction = Driver.merge(viewWillAppear, loadRetry)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.projects)
                return Action.makeDriver(response)
            }

        let myProjectSuccess = myProjectAction.elements
            .flatMap { [weak self] response -> Driver<[ProjectModel]> in
                guard let projects = try? response.map(to: [ProjectModel].self) else {
                    return Driver.empty()
                }
                self?.projectList = projects
                return Driver.just(projects)
            }

        let myProjectError = myProjectAction.error
            .flatMap { _ in Driver.just(() )}

        let showErrorPopup = myProjectError

        let embedEmptyView = myProjectSuccess
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if items.count == 0 {
                    return Driver.just(.myProjectListEmpty)
                }
                return Driver.empty()
        }

        let openCreateProjectViewController = input.createProjectBtnDidTap

        let openProjectViewController = input.selectedIndexPath

        let activityIndicator = myProjectAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            projectList: myProjectSuccess,
            openCreateProjectViewController: openCreateProjectViewController,
            openProjectViewController: openProjectViewController,
            embedEmptyViewController: embedEmptyView,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
