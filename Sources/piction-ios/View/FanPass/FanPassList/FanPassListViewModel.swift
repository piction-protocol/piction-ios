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

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let levelLimitChanged = levelLimit.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, loadRetry, refreshContent, refreshSession)

        let userInfoAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let currentUserInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
            }

        let currentUserInfoError = userInfoAction.error
            .flatMap { _ in Driver.just(UserModel.from([:])!) }

        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        let postItemAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let postId = self?.postId else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.get(uri: self?.uri ?? "", postId: postId))
                return Action.makeDriver(response)
            }

        let PostItemSuccess = postItemAction.elements
            .flatMap { [weak self] response -> Driver<PostModel> in
                guard let postItem = try? response.map(to: PostModel.self) else { return Driver.empty() }
                self?.levelLimit.onNext(postItem.fanPass?.level ?? 0)
                return Driver.just(postItem)
            }

        let subscriptionInfoAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.getProjectSubscription(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .flatMap { response -> Driver<SubscriptionModel?> in
                guard let subscriptionInfo = try? response.map(to: SubscriptionModel.self) else { return Driver.empty() }
                return Driver.just(subscriptionInfo)
            }

        let subscriptionInfoError = subscriptionInfoAction.error
            .flatMap { _ in Driver<SubscriptionModel?>.just(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let fanPassListAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.fanPassAll(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let fanPassListSuccess = fanPassListAction.elements
            .flatMap { response -> Driver<[FanPassModel]> in
                guard let fanPassList = try? response.map(to: [FanPassModel].self) else { return Driver.empty() }
                return Driver.just(fanPassList)
            }

        let fanPassListError = fanPassListAction.error
            .flatMap { response -> Driver<Void> in
                return Driver.just(())
            }

        let freeFanPassItem = fanPassListSuccess
            .flatMap { fanPassList -> Driver<FanPassModel?> in
                let freeFanPass = fanPassList.filter { ($0.level ?? 0) == 0 }.first

                return Driver.just(freeFanPass)
            }

        let fanPassTableItems = Driver.combineLatest(fanPassListSuccess, subscriptionInfo, levelLimitChanged)
            .flatMap { (fanPassList, subscriptionInfo, levelLimit) -> Driver<[FanPassListTableViewCellModel]> in

                let cellList = fanPassList.enumerated().map { (index, element) in FanPassListTableViewCellModel(fanPass: element, subscriptionInfo: subscriptionInfo, postCount: fanPassList[0...index].reduce(0) { $0 + ($1.postCount ?? 0) })
                }

                let filterList = cellList.filter { ($0.fanPass.level ?? 0) >= levelLimit }

                return Driver.just(filterList)
            }

        let projectInfoAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let projectInfoSuccess = projectInfoAction.elements
            .flatMap { response -> Driver<ProjectModel> in
                guard let projectInfo = try? response.map(to: ProjectModel.self) else { return Driver.empty() }
                return Driver.just(projectInfo)
            }

        let subscriptionFreeAction = input.subscribeFreeBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(subscriptionInfo)
            .filter { $0 == nil }
            .withLatestFrom(freeFanPassItem)
            .flatMap { [weak self] freeFanPassItem -> Driver<Action<ResponseData>> in

                let response = PictionSDK.rx.requestAPI(ProjectsAPI.subscription(uri: self?.uri ?? "", fanPassId: freeFanPassItem?.id ?? 0, subscriptionPrice: freeFanPassItem?.subscriptionPrice ?? 0))

                return Action.makeDriver(response)
            }

        let subscriptionFreeSuccess = subscriptionFreeAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.str_project_subscrition_complete.localized())
            }

        let subscriptionFreeError = subscriptionFreeAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                return Driver.just(errorMsg.message)
            }

        let cancelSubscriptionFreeAction = input.subscribeFreeBtnDidTap
            .withLatestFrom(subscriptionInfo)
            .filter { $0 != nil && ($0?.fanPass?.level ?? 0) == 0 }
            .withLatestFrom(freeFanPassItem)
            .flatMap { [weak self] freeFanPassItem -> Driver<Action<ResponseData>> in

                let response = PictionSDK.rx.requestAPI(ProjectsAPI.cancelSubscription(uri: self?.uri ?? "", fanPassId: freeFanPassItem?.id ?? 0))

                return Action.makeDriver(response)
            }

        let cancelSubscriptionFreeSuccess = cancelSubscriptionFreeAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.str_project_cancel_subscrition.localized())
            }

        let cancelSubscriptionFreeError = cancelSubscriptionFreeAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                return Driver.just(errorMsg.message)
            }

        let showErrorPopup = fanPassListError

        let showToast = Driver.merge(subscriptionFreeSuccess, subscriptionFreeError, cancelSubscriptionFreeSuccess, cancelSubscriptionFreeError)

        let activityIndicator = Driver.merge(
            fanPassListAction.isExecuting,
            subscriptionFreeAction.isExecuting,
            cancelSubscriptionFreeAction.isExecuting)

        let dismissViewController = input.closeBtnDidTap

        let selectedIndexPath = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(input.selectedIndexPath)

        let openSignInViewController = input.selectedIndexPath
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .flatMap { _ in Driver.just(()) }

        return Output(
            viewWillAppear: input.viewWillAppear,
            subscriptionInfo: subscriptionInfoSuccess,
            postItem: PostItemSuccess,
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
