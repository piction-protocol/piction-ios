//
//  CreatorProfileViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/18.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CreatorProfileViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let loginId: String

    init(dependency: Dependency) {
        (firebaseManager, loginId) = dependency
    }
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let embedCreatorProfileHeaderViewController: Driver<String>
        let creatorProjectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, loginId) = (self.firebaseManager, self.loginId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("크리에이터상세_\(loginId)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let embedCreatorProfileHeaderViewController = initialLoad
            .map { self.loginId }

        let creatorProjectAction = initialLoad
            .map { CreatorProfileAPI.getCreatorProfile(loginId: loginId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let creatorProjectSuccess = creatorProjectAction.elements
            .map { try? $0.map(to: [ProjectModel].self) }
            .flatMap(Driver.from)

        let creatorProjectError = creatorProjectAction.error
            .map { _ in [ProjectModel.from([:])!] }

        let dismissViewController = Driver.merge(creatorProjectSuccess, creatorProjectError)
            .filter { $0.isEmpty }
            .map { _ in LocalizationKey.msg_creator_not_found.localized() }

        let activityIndicator = creatorProjectAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            embedCreatorProfileHeaderViewController: embedCreatorProfileHeaderViewController,
            creatorProjectList: creatorProjectSuccess,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController
        )
    }
}
