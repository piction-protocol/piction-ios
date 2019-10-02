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
import RxPictionSDK

final class ProjectInfoViewModel: ViewModel {

    let uri: String

    init(uri: String) {
        self.uri = uri
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let sendDonationBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let openSendDonationViewController: Driver<String>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear

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
            .withLatestFrom(projectInfoSuccess)
            .flatMap { projectInfo -> Driver<String> in
                let loginId = projectInfo.user?.loginId ?? ""
                return Driver.just(loginId)
            }

        return Output(
            viewWillAppear: viewWillAppear,
            projectInfo: projectInfoSuccess,
            openSendDonationViewController: openSendDonationViewController
        )
    }
}
