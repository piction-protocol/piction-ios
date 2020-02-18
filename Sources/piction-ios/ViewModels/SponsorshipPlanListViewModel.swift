//
//  SponsorshipPlanListViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SponsorshipPlanListViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String
    private let postId: Int?

    var loadRetryTrigger = PublishSubject<Void>()
    var levelLimit = BehaviorSubject<Int>(value: 0)

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, postId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let showAllSponsorshipPlanBtnDidTap: Driver<Void>
        let subscribeFreeBtnDidTap: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let subscriptionInfo: Driver<SponsorshipModel?>
        let postItem: Driver<PostModel>
        let showAllSponsorshipPlanBtnDidTap: Driver<Void>
        let sponsorshipPlanList: Driver<[PlanModel]>
        let projectInfo: Driver<ProjectModel>
        let sponsorshipPlanTableItems: Driver<[SponsorshipPlanListTableViewCellModel]>
        let selectedIndexPath: Driver<IndexPath>
        let openSignInViewController: Driver<Void>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, postId) = (self.firebaseManager, self.updater, self.uri, self.postId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("SponsorshipPlan목록_\(uri)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let levelLimitChanged = levelLimit.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, loadRetry, refreshContent, refreshSession)

        let userInfoAction = loadPage
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let currentUserInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let currentUserInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        let postItemAction = loadPage
            .filter { postId != nil }
            .map { postId ?? 0 }
            .map { PostAPI.get(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let postItemSuccess = postItemAction.elements
            .map { try? $0.map(to: PostModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] postItem in
                guard let sponsorshipPlanLevel = postItem.plan?.level else { return }
                self?.levelLimit.onNext(sponsorshipPlanLevel)
            })

        let subscriptionInfoAction = loadPage
            .map { SponsorshipPlanAPI.getSponsoredPlan(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let sponsorshipPlanListAction = loadPage
            .map { SponsorshipPlanAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let sponsorshipPlanListSuccess = sponsorshipPlanListAction.elements
            .map { try? $0.map(to: [PlanModel].self) }
            .flatMap(Driver.from)

        let sponsorshipPlanListError = sponsorshipPlanListAction.error
            .map { _ in Void() }

        let freeSponsorshipPlanItem = sponsorshipPlanListSuccess
            .map { $0.filter { ($0.level ?? 0) == 0 }.first }

        let sponsorshipPlanTableItems = Driver.combineLatest(sponsorshipPlanListSuccess, subscriptionInfo, levelLimitChanged)
            .map { arg -> [SponsorshipPlanListTableViewCellModel] in
                let (sponsorshipPlanList, subscriptionInfo, levelLimit) = arg
                let cellList = sponsorshipPlanList.enumerated().map { (index, element) in SponsorshipPlanListTableViewCellModel(sponsorshipPlan: element, subscriptionInfo: subscriptionInfo, postCount: sponsorshipPlanList[0...index].reduce(0) { $0 + ($1.postCount ?? 0) }) }
                return cellList.filter { ($0.sponsorshipPlan.level ?? 0) >= levelLimit }
            }

        let projectInfoAction = loadPage
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let subscriptionFreeAction = input.subscribeFreeBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(subscriptionInfo)
            .filter { $0 == nil }
            .withLatestFrom(freeSponsorshipPlanItem)
            .map { SponsorshipPlanAPI.sponsorship(uri: uri, planId: $0?.id ?? 0, sponsorshipPrice: $0?.sponsorshipPrice ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionFreeSuccess = subscriptionFreeAction.elements
            .map { _ in LocalizationKey.str_project_subscrition_complete.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })
        
        let subscriptionFreeError = subscriptionFreeAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let cancelSubscriptionFreeAction = input.subscribeFreeBtnDidTap
            .withLatestFrom(subscriptionInfo)
            .filter { $0 != nil && ($0?.plan?.level ?? 0) == 0 }
            .withLatestFrom(freeSponsorshipPlanItem)
            .map { SponsorshipPlanAPI.cancelSponsorship(uri: uri, planId:
                $0?.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let cancelSubscriptionFreeSuccess = cancelSubscriptionFreeAction.elements
            .map { _ in LocalizationKey.str_project_cancel_subscrition.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let cancelSubscriptionFreeError = cancelSubscriptionFreeAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let selectedIndexPath = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(input.selectedIndexPath)

        let openSignInViewController = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let showErrorPopup = sponsorshipPlanListError

        let toastMessage = Driver.merge(subscriptionFreeSuccess, subscriptionFreeError, cancelSubscriptionFreeSuccess, cancelSubscriptionFreeError)

        let activityIndicator = Driver.merge(
            sponsorshipPlanListAction.isExecuting,
            subscriptionFreeAction.isExecuting,
            cancelSubscriptionFreeAction.isExecuting)

        let dismissViewController = input.closeBtnDidTap

        return Output(
            viewWillAppear: viewWillAppear,
            subscriptionInfo: subscriptionInfoSuccess,
            postItem: postItemSuccess,
            showAllSponsorshipPlanBtnDidTap: input.showAllSponsorshipPlanBtnDidTap,
            sponsorshipPlanList: sponsorshipPlanListSuccess,
            projectInfo: projectInfoSuccess,
            sponsorshipPlanTableItems: sponsorshipPlanTableItems,
            selectedIndexPath: selectedIndexPath,
            openSignInViewController: openSignInViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            toastMessage: toastMessage
        )
    }
}
