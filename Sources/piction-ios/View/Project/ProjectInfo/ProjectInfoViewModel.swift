//
//  ProjectInfoViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ProjectInfoViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    let updater: UpdaterProtocol
    let uri: String

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let selectedIndexPath: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let uri = self.uri

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let projectInfoAction = Driver.merge(viewWillAppear, refreshContent, loadRetry)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: uri))
                return Action.makeDriver(response)
            }

        let projectInfoSuccess = projectInfoAction.elements
            .flatMap { response -> Driver<ProjectModel> in
                guard let projectInfo = try? response.map(to: ProjectModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(projectInfo)
            }

        let projectInfoError = projectInfoAction.error
            .flatMap { _ in Driver.just(()) }

        let showErrorPopup = projectInfoError

        let activityIndicator = projectInfoAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            projectInfo: projectInfoSuccess,
            selectedIndexPath: input.selectedIndexPath,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
