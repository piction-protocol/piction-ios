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

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let sendDonationBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let openSendDonationViewController: Driver<String>
        let openSignInViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let userInfoAction = Driver.merge(viewWillAppear, refreshSession)
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

        let projectInfoAction = input.viewWillAppear
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

        return Output(
            viewWillAppear: input.viewWillAppear,
            projectInfo: projectInfoSuccess,
            openSendDonationViewController: openSendDonationViewController,
            openSignInViewController: openSignInViewController
        )
    }
}
