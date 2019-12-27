//
//  FanPassListViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class FanPassListViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int?
    )

    let updater: UpdaterProtocol
    let uri: String
    let postId: Int?

    var loadRetryTrigger = PublishSubject<Void>()
    var levelLimit = BehaviorSubject<Int>(value: 0)

    init(dependency: Dependency) {
        (updater, uri, postId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let showAllFanPassBtnDidTap: Driver<Void>
        let subscribeFreeBtnDidTap: Driver<Void>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let subscriptionInfo: Driver<SubscriptionModel?>
        let postItem: Driver<PostModel>
        let showAllFanPassBtnDidTap: Driver<Void>
        let fanPassList: Driver<[FanPassModel]>
        let projectInfo: Driver<ProjectModel>
        let fanPassTableItems: Driver<[FanPassListTableViewCellModel]>
        let selectedIndexPath: Driver<IndexPath>
        let openSignInViewController: Driver<Void>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri, postId) = (self.updater, self.uri, self.postId)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let levelLimitChanged = levelLimit.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, loadRetry, refreshContent, refreshSession)

        let userInfoAction = initialLoad
            .map { UsersAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let currentUserInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let currentUserInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        let postItemAction = initialLoad
            .filter { postId != nil }
            .map { postId ?? 0 }
            .map { PostsAPI.get(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let postItemSuccess = postItemAction.elements
            .map { try? $0.map(to: PostModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] postItem in
                guard let fanPassLevel = postItem.fanPass?.level else { return }
                self?.levelLimit.onNext(fanPassLevel)
            })

        let subscriptionInfoAction = initialLoad
            .map { ProjectsAPI.getProjectSubscription(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SubscriptionModel.self) }
            .flatMap(Driver<SubscriptionModel?>.from)

        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SubscriptionModel?(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let fanPassListAction = initialLoad
            .map { ProjectsAPI.fanPassAll(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let fanPassListSuccess = fanPassListAction.elements
            .map { try? $0.map(to: [FanPassModel].self) }
            .flatMap(Driver.from)

        let fanPassListError = fanPassListAction.error
            .map { _ in Void() }

        let freeFanPassItem = fanPassListSuccess
            .map { $0.filter { ($0.level ?? 0) == 0 }.first }

        let fanPassTableItems = Driver.combineLatest(fanPassListSuccess, subscriptionInfo, levelLimitChanged)
            .map { arg -> [FanPassListTableViewCellModel] in
                let (fanPassList, subscriptionInfo, levelLimit) = arg
                let cellList = fanPassList.enumerated().map { (index, element) in FanPassListTableViewCellModel(fanPass: element, subscriptionInfo: subscriptionInfo, postCount: fanPassList[0...index].reduce(0) { $0 + ($1.postCount ?? 0) }) }
                return cellList.filter { ($0.fanPass.level ?? 0) >= levelLimit }
            }

        let projectInfoAction = initialLoad
            .map { ProjectsAPI.get(uri: uri) }
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
            .withLatestFrom(freeFanPassItem)
            .map { ProjectsAPI.subscription(uri: uri, fanPassId: $0?.id ?? 0, subscriptionPrice: $0?.subscriptionPrice ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionFreeSuccess = subscriptionFreeAction.elements
            .map { _ in LocalizedStrings.str_project_subscrition_complete.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })
        
        let subscriptionFreeError = subscriptionFreeAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let cancelSubscriptionFreeAction = input.subscribeFreeBtnDidTap
            .withLatestFrom(subscriptionInfo)
            .filter { $0 != nil && ($0?.fanPass?.level ?? 0) == 0 }
            .withLatestFrom(freeFanPassItem)
            .map { ProjectsAPI.cancelSubscription(uri: uri, fanPassId:
                $0?.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let cancelSubscriptionFreeSuccess = cancelSubscriptionFreeAction.elements
            .map { _ in LocalizedStrings.str_project_cancel_subscrition.localized() }
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

        let showErrorPopup = fanPassListError

        let showToast = Driver.merge(subscriptionFreeSuccess, subscriptionFreeError, cancelSubscriptionFreeSuccess, cancelSubscriptionFreeError)

        let activityIndicator = Driver.merge(
            fanPassListAction.isExecuting,
            subscriptionFreeAction.isExecuting,
            cancelSubscriptionFreeAction.isExecuting)

        let dismissViewController = input.closeBtnDidTap

        return Output(
            viewWillAppear: input.viewWillAppear,
            subscriptionInfo: subscriptionInfoSuccess,
            postItem: postItemSuccess,
            showAllFanPassBtnDidTap: input.showAllFanPassBtnDidTap,
            fanPassList: fanPassListSuccess,
            projectInfo: projectInfoSuccess,
            fanPassTableItems: fanPassTableItems,
            selectedIndexPath: selectedIndexPath,
            openSignInViewController: openSignInViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            showToast: showToast
        )
    }
}
