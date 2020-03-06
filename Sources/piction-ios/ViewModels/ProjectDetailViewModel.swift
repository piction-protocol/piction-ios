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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension ProjectDetailViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let subscriptionBtnDidTap: Driver<Void>
        let cancelSubscriptionBtnDidTap: Driver<Void>
        let membershipBtnDidTap: Driver<Void>
        let creatorProfileBtnDidTap: Driver<Void>
        let subscriptionUserBtnDidTap: Driver<Void>
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
        let openSubscriptionUserViewController: Driver<String>
        let openSignInViewController: Driver<Void>
        let toastMessage: Driver<String>
    }
}

// MARK: - ViewModel Build
extension ProjectDetailViewModel {
    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 프로젝트 정보 호출
        let projectInfoAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 정보 호출 성공 시
        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        // 프로젝트 정보 호출 에러 시
        let projectInfoError = projectInfoAction.error
            .map { _ in ProjectModel.from([:])! }

        // 프로젝트 정보
        let projectInfo = Driver.merge(projectInfoSuccess, projectInfoError)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 후원중인 멤버십 호출
        let sponsoredMembershipAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map{ _ in MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 후원중인 멤버십 호출 성공 시
        let sponsoredMembershipSuccess = sponsoredMembershipAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        // 후원중인 멤버십 호출 에러 시
        let sponsoredMembershipError = sponsoredMembershipAction.error
            .map { _ in SponsorshipModel?(nil) }

        // 후원중인 멤버십
        let sponsoredMembership = Driver.merge(sponsoredMembershipSuccess, sponsoredMembershipError)

        // 최초 진입 시, 세션 갱신 시
        // 유저 정보 호출
        let currentUserInfoAction = Driver.merge(initialLoad, refreshSession)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let currentUserInfoSuccess = currentUserInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 유저 정보 호출 에러 시
        let currentUserInfoError = currentUserInfoAction.error
            .map { _ in UserModel.from([:])! }

        // 유저 정보
        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        // 크리에이터인지 확인
        let isWriter = Driver.combineLatest(projectInfo, currentUserInfo)
            .map { $0.user?.loginId == $1.loginId }

        // 크리에이터면 후원하기 버튼 숨김
        let membershipBtnHidden = isWriter
            .withLatestFrom(projectInfo) { (isWriter: $0, activeMembership: $1.activeMembership ?? false) }
            .map { $0 || !$1 }

        // 후원하기 버튼 누르면 후원 플랜 목록으로 이동
        let openMembershipListViewController = input.membershipBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .map { _ in self.uri }

        // 크리에이터 누르면 크리에이터 정보 화면으로 이동
        let openCreatorProfileViewController = input.creatorProfileBtnDidTap
            .withLatestFrom(projectInfo)
            .map { $0.user?.loginId }
            .flatMap(Driver.from)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 후원 플랜 목록 호출
        let membershipListAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 후원 플랜 목록 호출 성공 시
        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .flatMap(Driver.from)

        // 로그인 되어 있고 구독중이 아닐 때 구독하기 버튼 누르면
        // 구독 호출
        let subscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(sponsoredMembership)
            .filter { $0 == nil }
            .withLatestFrom(membershipListSuccess)
            .map { MembershipAPI.sponsorship(uri: uri, membershipId: $0[safe: 0]?.id ?? 0, sponsorshipPrice: $0[safe: 0]?.price ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독 호출 성공 시
        let subscriptionSuccess = subscriptionAction.elements
            .map { _ in LocalizationKey.str_project_subscrition_complete.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 구독 호출 에러 시
        let subscriptionError = subscriptionAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 로그인 되어 있고 구독 중일 때
        // 구독 취소 팝업 호출
        let openCancelSubscriptionPopup = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(sponsoredMembership)
            .filter { $0 != nil && ($0?.membership?.level ?? 0) == 0 }
            .map { _ in Void() }

        // 로그인 되어 있고 후원 중일 때
        // 구독 취소 불가능 팝업 호출
        let openNoCancellationSubscriptionPopup = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(sponsoredMembership)
            .filter { $0 != nil && ($0?.membership?.level ?? 0) > 0 }
            .map { _ in Void() }

        // 구독 취소 시
        // 구독 취소 호출
        let cancelSubscriptionAction = input.cancelSubscriptionBtnDidTap
           .withLatestFrom(sponsoredMembership)
           .filter { $0 != nil }
           .filter { ($0?.membership?.level ?? 0) == 0 }
           .map { MembershipAPI.cancelSponsorship(uri: uri, membershipId: $0?.membership?.id ?? 0) }
           .map(PictionSDK.rx.requestAPI)
           .flatMap(Action.makeDriver)

        // 구독 취소 성공 시
        let cancelSubscriptionSuccess = cancelSubscriptionAction.elements
           .map { _ in LocalizationKey.str_project_cancel_subscrition.localized() }
           .do(onNext: { _ in
               updater.refreshContent.onNext(())
           })

        // 구독 취소 에러 시
        let cancelSubscriptionError = cancelSubscriptionAction.error
           .map { $0 as? ErrorType }
           .map { $0?.message }
           .flatMap(Driver.from)

        // 크리에이터가 구독자 수 버튼 눌렀을 때 구독자 목록으로 이동
        let openSubscriptionUserViewController = input.subscriptionUserBtnDidTap
            .withLatestFrom(isWriter)
            .filter { $0 }
            .map { _ in self.uri }

        // 로그인 되지 않은 상태에서 구독 버튼, 후원 버튼 눌렀을 때
        // 로그인 화면 출력
        let openSignInViewController = Driver.merge(input.subscriptionBtnDidTap, input.membershipBtnDidTap)
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        // 토스트 메시지
        let toastMessage = Driver.merge(
            subscriptionSuccess,
            subscriptionError,
            cancelSubscriptionSuccess,
            cancelSubscriptionError)

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
            openSubscriptionUserViewController: openSubscriptionUserViewController,
            openSignInViewController: openSignInViewController,
            toastMessage: toastMessage
        )
    }
}

