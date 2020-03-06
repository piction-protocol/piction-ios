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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension ProjectInfoViewModel {
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
}

// MARK: - ViewModel Build
extension ProjectInfoViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, uri) = (self.firebaseManager, self.uri)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("프로젝트상세_정보_\(uri)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 컨텐츠의 내용 갱신 필요 시, 새로고침 필요 시
        // 프로젝트 정보 호출
        let projectInfoAction = Driver.merge(initialLoad, refreshContent, loadRetry)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 정보 호출 성공 시
        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        // 프로젝트 정보 호출 에러 시
        let projectInfoError = projectInfoAction.error
            .map { _ in Void() }

        // 크리에이터 눌렀을 때 크리에이터 정보 화면으로 이동
        let openCreatorProfileViewController = input.creatorBtnDidTap
            .withLatestFrom(projectInfoSuccess)
            .map { $0.user?.loginId }
            .flatMap(Driver.from)

        // 에러 팝업 출력
        let showErrorPopup = projectInfoError

        // 로딩 뷰
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
