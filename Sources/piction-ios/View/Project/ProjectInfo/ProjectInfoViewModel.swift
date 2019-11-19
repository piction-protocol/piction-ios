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
        let sendDonationBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let selectedIndexPath: Driver<IndexPath>
        let openSendDonationViewController: Driver<String>
        let openSignInViewController: Driver<Void>
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

        let openSendDonationViewController = input.sendDonationBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(projectInfoSuccess)
            .flatMap { projectInfo -> Driver<String> in
                let loginId = projectInfo.user?.loginId ?? ""
                return Driver.just(loginId)
            }

        let openSignInViewController = input.sendDonationBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .flatMap { _ in Driver.just(()) }

        let showActivityIndicator = projectInfoAction
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = projectInfoSuccess
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)
            .flatMap { status in Driver.just(status) }

        return Output(
            viewWillAppear: input.viewWillAppear,
            projectInfo: projectInfoSuccess,
            selectedIndexPath: input.selectedIndexPath,
            openSendDonationViewController: openSendDonationViewController,
            openSignInViewController: openSignInViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
