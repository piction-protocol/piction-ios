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
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let userInfoAction = Driver.merge(viewWillAppear, refreshSession, loadRetry)
               .flatMap { _ -> Driver<Action<ResponseData>> in
                   let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                   return Action.makeDriver(response)
               }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
            }

        let userInfoError = userInfoAction.error
            .flatMap { _ in Driver.just(UserModel.from([:])!) }

        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        let projectInfoAction = Driver.merge(viewWillAppear, loadRetry)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self?.uri ?? ""))
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
