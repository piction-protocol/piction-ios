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

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let showAllMembershipBtnDidTap: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let subscriptionInfo: Driver<SponsorshipModel?>
        let postItem: Driver<PostModel>
        let showAllMembershipBtnDidTap: Driver<Void>
        let membershipList: Driver<[MembershipModel]>
        let projectInfo: Driver<ProjectModel>
        let membershipTableItems: Driver<[MembershipListTableViewCellModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let openSignInViewController: Driver<Void>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, postId) = (self.firebaseManager, self.updater, self.uri, self.postId)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("Membership목록_\(uri)")
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
                guard let membershipLevel = postItem.membership?.level else { return }
                self?.levelLimit.onNext(membershipLevel)
            })

        let subscriptionInfoAction = loadPage
            .map { MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let membershipListAction = loadPage
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .map { $0?.filter { $0.level != 0 } }
            .flatMap(Driver.from)

        let membershipListError = membershipListAction.error
            .map { _ in Void() }

        let membershipTableItems = Driver.combineLatest(membershipListSuccess, subscriptionInfo, levelLimitChanged)
            .map { arg -> [MembershipListTableViewCellModel] in
                let (membershipList, subscriptionInfo, levelLimit) = arg
                let cellList = membershipList.enumerated().map { (index, element) in MembershipListTableViewCellModel(membership: element, subscriptionInfo: subscriptionInfo, postCount: membershipList[0...index].reduce(0) { $0 + ($1.postCount ?? 0) }) }
                return cellList.filter { ($0.membership.level ?? 0) >= levelLimit }
            }

        let embedEmptyViewController = membershipTableItems
            .map { $0.isEmpty }
            .map { _ in .membershipEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let projectInfoAction = loadPage
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let selectedIndexPath = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(input.selectedIndexPath)

        let openSignInViewController = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let showErrorPopup = membershipListError

        let activityIndicator = membershipListAction.isExecuting

        let dismissViewController = input.closeBtnDidTap

        return Output(
            viewWillAppear: viewWillAppear,
            subscriptionInfo: subscriptionInfoSuccess,
            postItem: postItemSuccess,
            showAllMembershipBtnDidTap: input.showAllMembershipBtnDidTap,
            membershipList: membershipListSuccess,
            projectInfo: projectInfoSuccess,
            membershipTableItems: membershipTableItems,
            embedEmptyViewController: embedEmptyViewController,
            selectedIndexPath: selectedIndexPath,
            openSignInViewController: openSignInViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController
        )
    }
}
