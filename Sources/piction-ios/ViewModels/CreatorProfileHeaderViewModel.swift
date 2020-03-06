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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension CreatorProfileHeaderViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let creatorProfile: Driver<CreatorProfileModel>
        let creatorInfo: Driver<UserModel>
        let creatorLinkList: Driver<[CreatorLinkModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension CreatorProfileHeaderViewModel {
    func build(input: Input) -> Output {
        let (updater, loginId) = (self.updater, self.loginId)

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 컨텐츠의 내용 갱신 필요 시
        // 크리에이터 정보 호출
        let creatorProfileAction = Driver.merge(initialLoad, refreshContent)
            .map { CreatorProfileAPI.createCreatorProfile(loginId: loginId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 크리에이터 정보 호출 성공 시
        let creatorProfileSuccess = creatorProfileAction.elements
            .map { try? $0.map(to: CreatorProfileModel.self) }
            .flatMap(Driver.from)

        // 크리에이터 정보 호출 에러 시
        let creatorProfileError = creatorProfileAction.error
            .map { _ in CreatorProfileModel.from([:])! }

        // 크리에이터 정보의 sns link
        let creatorLinkList = Driver.merge(creatorProfileSuccess, creatorProfileError)
            .map { $0.links ?? [] }

        // 최초 진입 시, 컨텐츠의 내용 갱신 필요 시
        // 유저 정보 호출
        let creatorInfoAction = Driver.merge(initialLoad, refreshContent)
            .map { _ in UserAPI.findOne(id: loginId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let creatorInfoSuccess = creatorInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 로딩 뷰
        let activityIndicator = creatorProfileAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            creatorProfile: creatorProfileSuccess,
            creatorInfo: creatorInfoSuccess,
            creatorLinkList: creatorLinkList,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator
        )
    }
}

