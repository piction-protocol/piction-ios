//
//  CreatorProfileHeaderViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/20.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CreatorProfileHeaderViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    private let updater: UpdaterProtocol
    private let loginId: String

    init(dependency: Dependency) {
        (updater, loginId) = dependency
    }
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let creatorProfile: Driver<CreatorProfileModel>
        let creatorInfo: Driver<UserModel>
        let creatorLinkList: Driver<[CreatorLinkModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let (updater, loginId) = (self.updater, self.loginId)

        let viewWillAppear = input.viewWillAppear

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let creatorProfileAction = Driver.merge(initialLoad, refreshContent)
            .map { CreatorProfileAPI.createCreatorProfile(loginId: loginId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let creatorProfileSuccess = creatorProfileAction.elements
            .map { try? $0.map(to: CreatorProfileModel.self) }
            .flatMap(Driver.from)

        let creatorProfileError = creatorProfileAction.error
            .map { _ in CreatorProfileModel.from([:])! }

        let creatorLinkList = Driver.merge(creatorProfileSuccess, creatorProfileError)
            .map { $0.links ?? [] }

        let creatorInfoAction = Driver.merge(initialLoad, refreshContent)
            .map { _ in UserAPI.findOne(id: loginId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let creatorInfoSuccess = creatorInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let activityIndicator = creatorProfileAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            creatorProfile: creatorProfileSuccess,
            creatorInfo: creatorInfoSuccess,
            creatorLinkList: creatorLinkList,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator
        )
    }
}

