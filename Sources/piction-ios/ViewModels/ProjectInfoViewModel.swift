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
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let uri: String

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let categoryCollectionViewSelectedIndexPath: Driver<IndexPath>
        let tagCollectionViewSelectedIndexPath: Driver<IndexPath>
        let creatorBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let categoryCollectionViewSelectedIndexPath: Driver<IndexPath>
        let tagCollectionViewSelectedIndexPath: Driver<IndexPath>
        let openCreatorProfileViewController: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, uri) = (self.firebaseManager, self.uri)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("프로젝트상세_정보_\(uri)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let projectInfoAction = Driver.merge(initialLoad, refreshContent, loadRetry)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let projectInfoError = projectInfoAction.error
            .map { _ in Void() }

        let openCreatorProfileViewController = input.creatorBtnDidTap
            .withLatestFrom(projectInfoSuccess)
            .map { $0.user?.loginId }
            .flatMap(Driver.from)

        let showErrorPopup = projectInfoError

        let activityIndicator = projectInfoAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            projectInfo: projectInfoSuccess,
            categoryCollectionViewSelectedIndexPath: input.categoryCollectionViewSelectedIndexPath,
            tagCollectionViewSelectedIndexPath: input.tagCollectionViewSelectedIndexPath,
            openCreatorProfileViewController: openCreatorProfileViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
