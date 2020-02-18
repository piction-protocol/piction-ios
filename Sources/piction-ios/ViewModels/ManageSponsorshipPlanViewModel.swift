//
//  ManageSponsorshipPlanViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ManageSponsorshipPlanViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String
    let planId: Int?

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, planId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let createBtnDidTap: Driver<Void>
        let deleteSponsorshipPlan: Driver<(String, Int)>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let sponsorshipPlanList: Driver<[PlanModel]>
        let selectedIndexPath: Driver<IndexPath>
        let openCreateSponsorshipPlanViewController: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, planId) = (self.firebaseManager, self.updater, self.uri, self.planId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("SponsorshipPlan관리_\(uri)_\(planId ?? 0)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, loadRetry, refreshContent)

        let sponsorshipPlanListAction = loadPage
            .map { SponsorshipPlanAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let sponsorshipPlanListSuccess = sponsorshipPlanListAction.elements
            .map { try? $0.map(to: [PlanModel].self) }
            .flatMap(Driver.from)

        let sponsorshipPlanListError = sponsorshipPlanListAction.error
            .map { _ in Void() }

        let openCreateSponsorshipPlanViewController = input.createBtnDidTap
            .map { uri }

        let deleteAction = input.deleteSponsorshipPlan
            .map { SponsorshipPlanAPI.delete(uri: $0, planId: $1) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deleteSuccess = deleteAction.elements
            .map { _ in LocalizationKey.msg_delete_sponsorship_plan_success.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let deleteError = deleteAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let showErrorPopup = sponsorshipPlanListError

        let activityIndicator = sponsorshipPlanListAction.isExecuting

        let dismissViewController = input.closeBtnDidTap

        let toastMessage = Driver.merge(deleteSuccess, deleteError)

        return Output(
            viewWillAppear: viewWillAppear,
            sponsorshipPlanList: sponsorshipPlanListSuccess,
            selectedIndexPath: input.selectedIndexPath,
            openCreateSponsorshipPlanViewController: openCreateSponsorshipPlanViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            toastMessage: toastMessage
        )
    }
}
