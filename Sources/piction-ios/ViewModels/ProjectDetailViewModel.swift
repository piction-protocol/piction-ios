//
//  ProjectDetailViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/21.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ProjectDetailViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    private let updater: UpdaterProtocol
    private let uri: String

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }
    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let subscriptionBtnDidTap: Driver<Void>
        let cancelSubscriptionBtnDidTap: Driver<Void>
        let membershipBtnDidTap: Driver<Void>
        let creatorProfileBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let isWriter: Driver<Bool>
        let sponsoredMembership: Driver<SponsorshipModel?>
        let membershipBtnHidden: Driver<Bool>
        let selectedIndexPath: Driver<IndexPath>
        let openCancelSubscriptionPopup: Driver<Void>
        let openNoCancellationSubscriptionPopup: Driver<Void>
        let openMembershipListViewController: Driver<String>
        let openCreatorProfileViewController: Driver<String>
        let openSignInViewController: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let projectInfoAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let projectInfoError = projectInfoAction.error
            .map { _ in ProjectModel.from([:])! }

        let projectInfo = Driver.merge(projectInfoSuccess, projectInfoError)

        let sponsoredMembershipAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map{ _ in MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let sponsoredMembershipSuccess = sponsoredMembershipAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        let sponsoredMembershipError = sponsoredMembershipAction.error
            .map { _ in SponsorshipModel?(nil) }

        let sponsoredMembership = Driver.merge(sponsoredMembershipSuccess, sponsoredMembershipError)

        let currentUserInfoAction = Driver.merge(initialLoad,  refreshSession)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let currentUserInfoSuccess = currentUserInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let currentUserInfoError = currentUserInfoAction.error
            .map { _ in UserModel.from([:])! }

        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        let isWriter = Driver.combineLatest(projectInfo, currentUserInfo)
            .map { $0.user?.loginId == $1.loginId }

        let membershipBtnHidden = isWriter
            .withLatestFrom(projectInfo) { (isWriter: $0, activeMembership: $1.activeMembership ?? false) }
            .map { $0 || !$1 }

        let openMembershipListViewController = input.membershipBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .map { _ in self.uri }

        let openCreatorProfileViewController = input.creatorProfileBtnDidTap
            .withLatestFrom(projectInfo)
            .map { $0.user?.loginId }
            .flatMap(Driver.from)

        let membershipListAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .flatMap(Driver.from)

        let subscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(sponsoredMembership)
            .filter { $0 == nil }
            .withLatestFrom(membershipListSuccess)
            .map { MembershipAPI.sponsorship(uri: uri, membershipId: $0[safe: 0]?.id ?? 0, sponsorshipPrice: $0[safe: 0]?.price ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionSuccess = subscriptionAction.elements
            .map { _ in LocalizationKey.str_project_subscrition_complete.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let subscriptionError = subscriptionAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let openCancelSubscriptionPopup = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(sponsoredMembership)
            .filter { $0 != nil && ($0?.membership?.level ?? 0) == 0 }
            .map { _ in Void() }

        let openNoCancellationSubscriptionPopup = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(sponsoredMembership)
            .filter { $0 != nil && ($0?.membership?.level ?? 0) > 0 }
            .map { _ in Void() }

        let cancelSubscriptionAction = input.cancelSubscriptionBtnDidTap
           .withLatestFrom(sponsoredMembership)
           .filter { $0 != nil }
           .filter { ($0?.membership?.level ?? 0) == 0 }
           .map { MembershipAPI.cancelSponsorship(uri: uri, membershipId: $0?.membership?.id ?? 0) }
           .map(PictionSDK.rx.requestAPI)
           .flatMap(Action.makeDriver)
//
        let cancelSubscriptionSuccess = cancelSubscriptionAction.elements
           .map { _ in LocalizationKey.str_project_cancel_subscrition.localized() }
           .do(onNext: { _ in
               updater.refreshContent.onNext(())
           })

        let cancelSubscriptionError = cancelSubscriptionAction.error
           .map { $0 as? ErrorType }
           .map { $0?.message }
           .flatMap(Driver.from)

        let openSignInViewController = Driver.merge(input.subscriptionBtnDidTap, input.membershipBtnDidTap)
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let toastMessage = Driver.merge(subscriptionSuccess, subscriptionError, cancelSubscriptionSuccess, cancelSubscriptionError)

        return Output(
            viewWillAppear: viewWillAppear,
            projectInfo: projectInfo,
            isWriter: isWriter,
            sponsoredMembership: sponsoredMembership,
            membershipBtnHidden: membershipBtnHidden,
            selectedIndexPath: input.selectedIndexPath,
            openCancelSubscriptionPopup: openCancelSubscriptionPopup,
            openNoCancellationSubscriptionPopup: openNoCancellationSubscriptionPopup,
            openMembershipListViewController: openMembershipListViewController,
            openCreatorProfileViewController: openCreatorProfileViewController,
            openSignInViewController: openSignInViewController,
            toastMessage: toastMessage
        )
    }
}

