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
        let shareBarBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let shareProject: Driver<String>
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

        let shareProject = input.shareBarBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                var infoDictionary: [AnyHashable: Any] = Bundle.main.infoDictionary!
                let appID: String = infoDictionary["CFBundleIdentifier"] as! String
                let isStaging = appID == "com.pictionnetwork.piction-test" ? "staging." : ""

                let url = "https://\(isStaging)piction.network/project/\(self.uri)"
                return Driver.just(url)
            }

        return Output(
            viewWillAppear: viewWillAppear,
            projectInfo: projectInfoSuccess,
            shareProject: shareProject,
            openSendDonationViewController: openSendDonationViewController
        )
    }
}
