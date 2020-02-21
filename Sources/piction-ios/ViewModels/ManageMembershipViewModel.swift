//
//  ManageMembershipViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ManageMembershipViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String
    let membershipId: Int?

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, membershipId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let createBtnDidTap: Driver<Void>
        let deleteMembership: Driver<(String, Int)>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let membershipList: Driver<[MembershipModel]>
        let selectedIndexPath: Driver<IndexPath>
        let openCreateMembershipViewController: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, membershipId) = (self.firebaseManager, self.updater, self.uri, self.membershipId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("Membership관리_\(uri)_\(membershipId ?? 0)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, loadRetry, refreshContent)

        let membershipListAction = loadPage
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .flatMap(Driver.from)

        let membershipListError = membershipListAction.error
            .map { _ in Void() }

        let openCreateMembershipViewController = input.createBtnDidTap
            .map { uri }

        let deleteAction = input.deleteMembership
            .map { MembershipAPI.delete(uri: $0, membershipId: $1) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deleteSuccess = deleteAction.elements
            .map { _ in LocalizationKey.msg_delete_membership_success.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let deleteError = deleteAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let showErrorPopup = membershipListError

        let activityIndicator = membershipListAction.isExecuting

        let dismissViewController = input.closeBtnDidTap

        let toastMessage = Driver.merge(deleteSuccess, deleteError)

        return Output(
            viewWillAppear: viewWillAppear,
            membershipList: membershipListSuccess,
            selectedIndexPath: input.selectedIndexPath,
            openCreateMembershipViewController: openCreateMembershipViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            toastMessage: toastMessage
        )
    }
}
