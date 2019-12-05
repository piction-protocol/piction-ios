//
//  PostViewModel.swift
//  PictionView
//
//  Created by jhseo on 01/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class PostViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int
    )

    private let updater: UpdaterProtocol
    var uri: String = ""
    var postId: Int = 0

    init(dependency: Dependency) {
        (updater, uri, postId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let loadPost: Driver<Int>
        let prevPostBtnDidTap: Driver<Void>
        let nextPostBtnDidTap: Driver<Void>
        let subscriptionBtnDidTap: Driver<Void>
        let shareBarBtnDidTap: Driver<Void>
        let contentOffset: Driver<CGPoint>
        let willBeginDecelerating: Driver<Void>
        let readmodeBarButton: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let prevPostIsEnabled: Driver<PostModel>
        let nextPostIsEnabled: Driver<PostModel>
        let showPostContent: Driver<String>
        let showNeedSubscription: Driver<(UserModel, PostModel, SubscriptionModel?)>
        let headerInfo: Driver<(PostModel, UserModel)>
        let footerInfo: Driver<(String, PostModel)>
        let activityIndicator: Driver<Bool>
        let contentOffset: Driver<CGPoint>
        let willBeginDecelerating: Driver<Void>
        let changeReadmode: Driver<Void>
        let openSignInViewController: Driver<Void>
        let openFanPassListViewController: Driver<(String, Int?)>
        let reloadPost: Driver<Void>
        let sharePost: Driver<String>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let postContentAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.content(uri: self?.uri ?? "", postId: self?.postId ?? 0))
                return Action.makeDriver(response)
            }

        let postContentSuccess = postContentAction.elements
            .flatMap { response -> Driver<String> in
                guard
                    let postItem = try? response.map(to: ContentModel.self),
                    let path = Bundle.main.path(forResource: "postStyle", ofType: "css"),
                    let cssString = try? String(contentsOfFile: path).components(separatedBy: .newlines).joined()
                else {
                    return Driver.just("")
                }
                let content = """
                    <meta name="viewport" content="initial-scale=1.0" />
                    \(cssString)
                    <body>\(postItem.content ?? "")</body>
                """
                return Driver.just(content)
            }

        let postContentError = postContentAction.error
            .flatMap { response -> Driver<String> in
                return Driver.just("")
            }

        let showPostContent = Driver.merge(postContentSuccess, postContentError)

        let prevPostAction = Driver.merge(viewWillAppear, refreshContent)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.prevPost(uri: self.uri, postId: self.postId))
                return Action.makeDriver(response)
            }

        let prevPostSuccess = prevPostAction.elements
            .flatMap { response -> Driver<PostModel> in
                guard let postItem = try? response.map(to: PostModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(postItem)
            }

        let prevPostError = prevPostAction.error
            .flatMap { response -> Driver<PostModel> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                switch errorMsg {
                case .notFound(let error):
                    return Driver.just(PostModel.from([:])!)
                default:
                    return Driver.empty()
                }
            }

        let prevPostIsEnabled = Driver.merge(prevPostSuccess, prevPostError)

        let prevPostBtnDidTap = input.prevPostBtnDidTap
            .withLatestFrom(prevPostSuccess)
            .flatMap { [weak self] postItem -> Driver<(String, Int)> in
                return Driver.just((self?.uri ?? "", postItem.id ?? 0))
            }

        let nextPostAction = Driver.merge(viewWillAppear, refreshContent)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.nextPost(uri: self.uri, postId: self.postId))
                return Action.makeDriver(response)
            }

        let nextPostSuccess = nextPostAction.elements
            .flatMap { response -> Driver<PostModel> in
                guard let postItem = try? response.map(to: PostModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(postItem)
            }

        let nextPostError = nextPostAction.error
            .flatMap { response -> Driver<PostModel> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                switch errorMsg {
                case .notFound(let error):
                    return Driver.just(PostModel.from([:])!)
                default:
                    return Driver.empty()
                }
            }

        let nextPostIsEnabled = Driver.merge(nextPostSuccess, nextPostError)

        let nextPostBtnDidTap = input.nextPostBtnDidTap
            .withLatestFrom(nextPostSuccess)
            .flatMap { [weak self] postItem -> Driver<(String, Int)> in
                return Driver.just((self?.uri ?? "", postItem.id ?? 0))
            }

        let loadPost = input.loadPost
            .flatMap { [weak self] postId -> Driver<(String, Int)> in
                Driver.just((self?.uri ?? "", postId))
            }

        let changePost = Driver.merge(loadPost, prevPostBtnDidTap, nextPostBtnDidTap)
            .flatMap { [weak self] (uri, postId) -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.uri = uri
                self.postId = postId
                self.updater.refreshContent.onNext(())
                return Driver.just(())
            }

        let reloadPost = Driver.merge(changePost, refreshContent, refreshSession)

        let projectInfoAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let writerInfo = projectInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let writerInfo = try? response.map(to: ProjectModel.self).user else {
                    return Driver.empty()
                }
                return Driver.just(writerInfo)
            }

        let postItemAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.get(uri: self?.uri ?? "", postId: self?.postId ?? 0))
                return Action.makeDriver(response)
            }

        let postItemSuccess = postItemAction.elements
            .flatMap { response -> Driver<PostModel> in
                guard let postItem = try? response.map(to: PostModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(postItem)
            }

        let headerInfo = Driver.zip(postItemSuccess, writerInfo)
            .flatMap { Driver.just(($0, $1)) }

        let userInfoAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { response -> Driver<UserModel> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo)
        }

        let userInfoError = userInfoAction.error
            .flatMap { response -> Driver<UserModel> in
                return Driver.just(UserModel.from([:])!)
        }

        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        let subscriptionInfoAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.getProjectSubscription(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .flatMap { response -> Driver<SubscriptionModel?> in
                guard let subscriptionInfo = try? response.map(to: SubscriptionModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(subscriptionInfo)
            }

        let subscriptionInfoError = subscriptionInfoAction.error
            .flatMap { _ in Driver<SubscriptionModel?>.just(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let needSubscription = Driver.zip(postItemSuccess, subscriptionInfo, userInfo, writerInfo)
            .flatMap { (postItem, subscriptionInfo, currentUser, writerInfo) -> Driver<Bool> in

                var needSubscription: Bool {
                    if currentUser.loginId ?? "" == writerInfo.loginId ?? "" {
                        return false
                    }
                    if postItem.fanPass == nil {
                        return false
                    }
                    if (postItem.fanPass?.level != nil) && (subscriptionInfo?.fanPass?.level == nil) {
                        return true
                    }
                    if (postItem.fanPass?.level ?? 0) <= (subscriptionInfo?.fanPass?.level ?? 0) {
                        return false
                    }
                    return true
                }
                return Driver.just(needSubscription)
            }

        let footerInfo = postItemSuccess
            .flatMap { [weak self] postItem -> Driver<(String, PostModel)> in
                return Driver.just((self?.uri ?? "", postItem))
            }

        let fanPassListAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.fanPassAll(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let fanPassListSuccess = fanPassListAction.elements
            .flatMap { response -> Driver<[FanPassModel]> in
                guard let fanPassList = try? response.map(to: [FanPassModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(fanPassList)
            }

        let needSubscriptionInfo = Driver.combineLatest(userInfo, postItemSuccess, subscriptionInfo)

        let showNeedSubscription = needSubscription
            .filter { $0 }
            .withLatestFrom(needSubscriptionInfo)

        let freeSubscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(postItemSuccess)
            .filter { ($0.fanPass?.level ?? 0) == 0 }
            .withLatestFrom(fanPassListSuccess)
            .flatMap { [weak self] fanPassList -> Driver<Action<ResponseData>> in
                let fanPassId = fanPassList.filter { ($0.level ?? 0) == 0 }.first?.id ?? 0
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.subscription(uri: self?.uri ?? "", fanPassId: fanPassId, subscriptionPrice: 0))
                return Action.makeDriver(response)
            }

        let freeSubscriptionSuccess = freeSubscriptionAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.str_project_subscrition_complete.localized())
            }

        let freeSubscriptionError = freeSubscriptionAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                return Driver.just(errorMsg.message)
            }

        let openFanPassListViewController = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(postItemSuccess)
            .filter { ($0.fanPass?.level ?? 0) > 0 }
            .flatMap { [weak self] _ -> Driver<(String, Int?)> in
                return Driver.just((self?.uri ?? "", self?.postId))
            }

        let activityIndicator = Driver.merge(
            postItemAction.isExecuting,
            freeSubscriptionAction.isExecuting)

        let openSignInViewController = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .flatMap { _ in Driver.just(()) }

        let sharePost = input.shareBarBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                let stagingPath = AppInfo.isStaging ? "staging." : ""

                let url = "https://\(stagingPath)piction.network/project/\(self.uri)/posts/\(self.postId)"
                return Driver.just(url)
            }

        let showToast = Driver.merge(freeSubscriptionSuccess, freeSubscriptionError)

        let contentOffset = Driver.combineLatest(input.contentOffset, input.viewDidAppear)
            .flatMap { (contentOffset, _) -> Driver<CGPoint> in
                return Driver.just(contentOffset)
            }

        let willBeginDecelerating = input.willBeginDecelerating

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewDidAppear: input.viewDidAppear,
            viewWillDisappear: input.viewWillDisappear,
            prevPostIsEnabled: prevPostIsEnabled,
            nextPostIsEnabled: nextPostIsEnabled,
            showPostContent: showPostContent,
            showNeedSubscription: showNeedSubscription,
            headerInfo: headerInfo,
            footerInfo: footerInfo,
            activityIndicator: activityIndicator,
            contentOffset: contentOffset,
            willBeginDecelerating: willBeginDecelerating,
            changeReadmode: input.readmodeBarButton,
            openSignInViewController: openSignInViewController,
            openFanPassListViewController: openFanPassListViewController,
            reloadPost: reloadPost,
            sharePost: sharePost,
            showToast: showToast
        )
    }
}
