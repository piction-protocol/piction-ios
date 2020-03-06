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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension CreatorProfileViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let embedCreatorProfileHeaderViewController: Driver<String>
        let creatorProjectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
        let popViewController: Driver<String>
    }
}

// MARK: - ViewModel Build
extension CreatorProfileViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, loginId) = (self.firebaseManager, self.loginId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("크리에이터상세_\(loginId)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시
        // header embed
        let embedCreatorProfileHeaderViewController = initialLoad
            .map { self.loginId }

        // 최초 진입 시
        // 크리에이터 정보 호출
        let creatorProjectAction = initialLoad
            .map { CreatorProfileAPI.getCreatorProfile(loginId: loginId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 크리에이터 프로젝트 호출 성공 시
        let creatorProjectSuccess = creatorProjectAction.elements
            .map { try? $0.map(to: [ProjectModel].self) }
            .flatMap(Driver.from)

        // 크리에이터 프로젝트 호출 에러 시
        let creatorProjectError = creatorProjectAction.error
            .map { _ in [ProjectModel.from([:])!] }

        // 크리에이터 프로젝트가 없을 경우 pop
        let popViewController = Driver.merge(creatorProjectSuccess, creatorProjectError)
            .filter { $0.isEmpty }
            .map { _ in LocalizationKey.msg_creator_not_found.localized() }

        // 로딩 뷰
        let activityIndicator = creatorProjectAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            embedCreatorProfileHeaderViewController: embedCreatorProfileHeaderViewController,
            creatorProjectList: creatorProjectSuccess,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator,
            popViewController: popViewController
        )
    }
}
