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
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let prevPostIsEnabled: Driver<PostModel>
        let nextPostIsEnabled: Driver<PostModel>
        let showPostContent: Driver<String>
        let showNeedSubscription: Driver<UserModel>
        let headerInfo: Driver<(PostModel, UserModel)>
        let footerInfo: Driver<(String, PostModel)>
        let activityIndicator: Driver<Bool>
        let contentOffset: Driver<CGPoint>
        let willBeginDecelerating: Driver<Void>
        let openSignInViewController: Driver<Void>
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
                guard let postItem = try? response.map(to: ContentModel.self) else {
                    return Driver.just("")
                }

                let content = "<style type=\"text/css\"> body { font: -apple-system-body; margin: 220px 20px 747px 20px; line-height: 28px; } p { margin: 0px; word-wrap: break-word; } img { max-height: 100%; width: calc(100% + 40px); margin-left: -20px; margin-right: -20px; !important; } .video { position: relative; padding-bottom: 56.25%; height: 0; } iframe { position: absolute; top: 0; left: 0; width: calc(100% + 40px); margin-left: -20px; margin-right: -20px; height: 100%; }</style><meta name=\"viewport\" content=\"initial-scale=1.0\" /><body>\(postItem.content ?? "")</body>"
                print(postItem.content)
                return Driver.just(content)
            }

        let postContentError = postContentAction.error
            .flatMap { response -> Driver<String> in
                let content = "<style type=\"text/css\"> body { font: -apple-system-body; margin: 220px 20px 278px 20px; } </style><meta name=\"viewport\" content=\"initial-scale=1.0\" /><body></body>"
                return Driver.just(content)
            }

        let showPostContent = Driver.merge(postContentSuccess, postContentError)

        let prevPostAction = Driver.merge(viewWillAppear, refreshContent)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.prevPost(uri: self?.uri ?? "", postId: self?.postId ?? 0))
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
                let response = PictionSDK.rx.requestAPI(PostsAPI.nextPost(uri: self?.uri ?? "", postId: self?.postId ?? 0))
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
                let errorMsg = response as? ErrorType

                switch errorMsg! {
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
                let response = PictionSDK.rx.requestAPI(FanPassAPI.isSubscription(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .flatMap { response -> Driver<SubscriptionModel> in
                guard let isSubscribing = try? response.map(to: SubscriptionModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(isSubscribing)
            }

        let subscriptionInfoError = subscriptionInfoAction.error
            .flatMap { _ in Driver.just(SubscriptionModel.from([:])!)}

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let needSubscription = Driver.zip(postItemSuccess, subscriptionInfo, userInfo, writerInfo)
            .flatMap { (postItem, subscriptionInfo, currentUser, writerInfo) -> Driver<Bool> in

                if (postItem.fanPass == nil
                    || (subscriptionInfo.fanPass != nil
                    && (postItem.fanPass != nil && subscriptionInfo.fanPass != nil && (postItem.fanPass?.level ?? 0 <= subscriptionInfo.fanPass?.level ?? 0)))
                    || (currentUser.loginId ?? "" == writerInfo.loginId ?? "")) {
                    return Driver.just(false)
                }
                return Driver.just(true)
            }

        let showNeedSubscription = needSubscription
            .filter { $0 }
            .withLatestFrom(userInfo)
            .flatMap { userInfo -> Driver<UserModel> in
                return Driver.just(userInfo)
            }

        let footerInfo = postItemSuccess
            .flatMap { [weak self] postItem -> Driver<(String, PostModel)> in
                return Driver.just((self?.uri ?? "", postItem))
            }

        let fanPassListAction = Driver.merge(viewWillAppear, refreshContent, refreshSession)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(FanPassAPI.projectAll(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let fanPassListSuccess = fanPassListAction.elements
            .flatMap { response -> Driver<[FanPassModel]> in
                guard let fanPassList = try? response.map(to: [FanPassModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(fanPassList)
            }

        let subscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(fanPassListSuccess)
            .flatMap { fanPassList -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(FanPassAPI.subscription(fanPassId: fanPassList[safe: 0]?.id ?? 0, subscriptionPrice: fanPassList[safe: 0]?.subscriptionPrice ?? 0))
                return Action.makeDriver(response)
            }

        let subscriptionSuccess = subscriptionAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.str_project_subscrition_complete.localized())
            }

        let subscriptionError = subscriptionAction.error
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

        let showToast = Driver.merge(subscriptionSuccess, subscriptionError)

        let contentOffset = Driver.combineLatest(input.contentOffset, input.viewDidAppear)
            .flatMap { (contentOffset, _) -> Driver<CGPoint> in
                return Driver.just(contentOffset)
            }

        let willBeginDecelerating = Driver.combineLatest(input.willBeginDecelerating, input.viewDidAppear)
            .flatMap { _ -> Driver<Void> in
                return Driver.just(())
            }

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
            openSignInViewController: openSignInViewController,
            reloadPost: reloadPost,
            sharePost: sharePost,
            showToast: showToast
        )
    }
}
