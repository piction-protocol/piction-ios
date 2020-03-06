//
//  MembershipListViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ViewModel
final class MembershipListViewModel: InjectableViewModel {

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
}

// MARK: - Input & Output
extension MembershipListViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let showAllMembershipBtnDidTap: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let subscriptionInfo: Driver<SponsorshipModel?>
        let postInfo: Driver<PostModel>
        let showAllMembershipBtnDidTap: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let membershipList: Driver<[MembershipListTableViewCellModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let openSignInViewController: Driver<Void>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension MembershipListViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, postId) = (self.firebaseManager, self.updater, self.uri, self.postId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("Membership목록_\(uri)")
            })

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

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 레벨 제한이 걸려있을 경우
        let levelLimitChanged = levelLimit
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 시, 새로고침 필요 시
        let loadPage = Driver.merge(initialLoad, refreshSession, refreshContent, loadRetry)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 시, 새로고침 필요 시
        // 유저 정보 호출
        let currentUserInfoAction = loadPage
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

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 시, 새로고침 필요 시
        // 포스트 정보 호출
        let postInfoAction = loadPage
            .filter { postId != nil }
            .map { postId ?? 0 }
            .map { PostAPI.get(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트 정보 호출 성공 시
        let postInfoSuccess = postInfoAction.elements
            .map { try? $0.map(to: PostModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] postItem in
                guard let membershipLevel = postItem.membership?.level else { return }
                self?.levelLimit.onNext(membershipLevel)
            })

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 시, 새로고침 필요 시
        // 구독중인 멤버십 호출
        let subscriptionInfoAction = loadPage
            .map { MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독중인 멤버십 호출 성공 시
        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        // 구독중인 멤버십 호출 에러 시
        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        // 구독중인 멤버십
        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 시, 새로고침 필요 시
        // 멤버십 목록 호출
        let membershipListAction = loadPage
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 멤버십 목록 호출 성공 시
        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .map { $0?.filter { $0.level != 0 } }
            .flatMap(Driver.from)

        // 멤버십 목록 호출 에러 시
        let membershipListError = membershipListAction.error
            .map { _ in Void() }

        // 멤버십 목록 호출 성공 시, 구독중인 멤버십 목록, 레벨 제한 여부을 조합
        // 멤버십 목록
        let membershipList = Driver.combineLatest(membershipListSuccess, subscriptionInfo, levelLimitChanged)
            .map { arg -> [MembershipListTableViewCellModel] in
                let (membershipList, subscriptionInfo, levelLimit) = arg
                let cellList = membershipList.enumerated().map { (index, element) in MembershipListTableViewCellModel(membership: element, subscriptionInfo: subscriptionInfo, postCount: membershipList[0...index].reduce(0) { $0 + ($1.postCount ?? 0) }) }
                return cellList.filter { ($0.membership.level ?? 0) >= levelLimit }
            }

        // 멤버십 목록이 없는 경우 emptyView 출력
        let embedEmptyViewController = membershipList
            .filter { $0.isEmpty }
            .map { _ in .membershipEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 시, 새로고침 필요 시
        // 프로젝트 정보 호출
        let projectInfoAction = loadPage
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 정보 호출 성공 시
        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        // tableView의 row 선택했을 때
        let selectedIndexPath = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(input.selectedIndexPath)

        // 로그인 안한 유저가 후원 플랜 선택했을 때 로그인 화면 출력
        let openSignInViewController = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        // 에러 팝업 출력
        let showErrorPopup = membershipListError

        // 로딩 뷰
        let activityIndicator = membershipListAction.isExecuting

        // 닫기 버튼 눌렀을 때 dismiss
        let dismissViewController = input.closeBtnDidTap

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            subscriptionInfo: subscriptionInfoSuccess,
            postInfo: postInfoSuccess,
            showAllMembershipBtnDidTap: input.showAllMembershipBtnDidTap,
            projectInfo: projectInfoSuccess,
            membershipList: membershipList,
            embedEmptyViewController: embedEmptyViewController,
            selectedIndexPath: selectedIndexPath,
            openSignInViewController: openSignInViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController
        )
    }
}
