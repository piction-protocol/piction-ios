//
//  PostViewModel.swift
//  PictionView
//
//  Created by jhseo on 01/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import Kanna
import PictionSDK

final class PostViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let uri: String
    var postId: Int = 0

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, postId) = dependency
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
        let prevNextLink: Driver<PostLinkModel>
        let showPostContent: Driver<String>
        let showNeedSubscription: Driver<(UserModel, PostModel, SubscriptionModel?)>
        let hideNeedSubscription: Driver<Bool>
        let headerInfo: Driver<(PostModel, UserModel)>
        let footerInfo: Driver<(String, PostModel)>
        let activityIndicator: Driver<Bool>
        let contentOffset: Driver<CGPoint>
        let willBeginDecelerating: Driver<Void>
        let changeReadmode: Driver<Void>
        let openSignInViewController: Driver<Void>
        let openFanPassListViewController: Driver<(String, Int)>
        let reloadPost: Driver<Void>
        let sharePost: Driver<String>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri) = (self.firebaseManager, self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("포스트뷰어_\(uri)_\(self.postId)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let postContentAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { PostAPI.getContent(uri: uri, postId: self.postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let postContentSuccess = postContentAction.elements
            .map { try? $0.map(to: ContentModel.self) }
            .map { postItem -> String in
                guard
                    let path = Bundle.main.path(forResource: "postStyle", ofType: "css"),
                    let cssString = try? String(contentsOfFile: path).components(separatedBy: .newlines).joined()
                else { return "" }

                return """
                    <meta name="viewport" content="initial-scale=1.0" />
                    \(cssString)
                    <body>\(postItem?.content ?? "")</body>
                """
            }

        let postContentError = postContentAction.error
            .map { _ in "" }

        let showPostContent = Driver.merge(postContentSuccess, postContentError)

        let prevNextLinkAction = Driver.merge(initialLoad, refreshContent)
            .map { PostAPI.getLinks(uri: uri, postId: self.postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let prevNextLinkSuccess = prevNextLinkAction.elements
            .map { try? $0.map(to: PostLinkModel.self) }
            .flatMap(Driver.from)

        let prevNextLinkError = prevNextLinkAction.error
            .map { _ in PostLinkModel.from([:])! }

        let prevNextLink = Driver.merge(prevNextLinkSuccess, prevNextLinkError)

        let prevPostBtnDidTap = input.prevPostBtnDidTap
            .withLatestFrom(prevNextLinkSuccess)
            .map { $0.previousPost?.id }
            .flatMap(Driver.from)

        let nextPostBtnDidTap = input.nextPostBtnDidTap
            .withLatestFrom(prevNextLinkSuccess)
            .map { $0.nextPost?.id }
            .flatMap(Driver.from)

        let loadPost = input.loadPost

        let changePost = Driver.merge(loadPost, prevPostBtnDidTap, nextPostBtnDidTap)
            .do(onNext: { [weak self] postId in
                self?.postId = postId
                updater.refreshContent.onNext(())
            })
            .map { _ in Void() }

        let reloadPost = changePost

        let projectInfoAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let writerInfo = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .map { $0?.user }
            .flatMap(Driver.from)

        let postItemAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { PostAPI.get(uri: uri, postId: self.postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let postItemSuccess = postItemAction.elements
            .map { try? $0.map(to: PostModel.self) }
            .flatMap(Driver.from)

        let headerInfo = Driver.zip(postItemSuccess, writerInfo)

        let userInfoAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let userInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        let subscriptionInfoAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { FanPassAPI.getSubscribedFanPass(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SubscriptionModel.self) }
            .flatMap(Driver<SubscriptionModel?>.from)

        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SubscriptionModel?(nil) }

        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let needSubscription = Driver.zip(postItemSuccess, subscriptionInfo, userInfo, writerInfo)
            .map { (postItem, subscriptionInfo, currentUser, writerInfo) -> Bool in
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

        let footerInfo = postItemSuccess
            .map { (uri, $0) }

        let fanPassListAction = Driver.merge(initialLoad, refreshContent, refreshSession)
            .map { FanPassAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let fanPassListSuccess = fanPassListAction.elements
            .map { try? $0.map(to: [FanPassModel].self) }
            .flatMap(Driver.from)

        let needSubscriptionInfo = Driver.combineLatest(userInfo, postItemSuccess, subscriptionInfo)

        let showNeedSubscription = needSubscription
            .filter { $0 }
            .withLatestFrom(needSubscriptionInfo)

        let hideNeedSubscription = needSubscription
            .filter { !$0 }
            .map { !$0 }

        let freeSubscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(postItemSuccess)
            .filter { ($0.fanPass?.level ?? 0) == 0 }
            .withLatestFrom(fanPassListSuccess)
            .map { $0.filter { ($0.level ?? 0) == 0 }.first?.id ?? 0 }
            .map { FanPassAPI.subscription(uri: uri, fanPassId: $0, subscriptionPrice: 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let freeSubscriptionSuccess = freeSubscriptionAction.elements
            .map { _ in LocalizationKey.str_project_subscrition_complete.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let freeSubscriptionError = freeSubscriptionAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let openFanPassListViewController = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(postItemSuccess)
            .filter { ($0.fanPass?.level ?? 0) > 0 }
            .map { _ in (uri, self.postId) }

        let activityIndicator = Driver.merge(
            postItemAction.isExecuting,
            freeSubscriptionAction.isExecuting)

        let openSignInViewController = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let sharePost = input.shareBarBtnDidTap
            .map { AppInfo.isStaging ? "staging." : "" }
            .map { "https://\($0)piction.network/project/\(uri)/posts/\(self.postId)" }
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                let stagingPath = AppInfo.isStaging ? "staging." : ""
                let url = "https://\(stagingPath)piction.network/project/\(uri)/posts/\(self.postId)"
                return Driver.just(url)
            }

        let toastMessage = Driver.merge(freeSubscriptionSuccess, freeSubscriptionError)

        let contentOffset = Driver.combineLatest(input.contentOffset, input.viewDidAppear)
            .map { $0.0 }

        let willBeginDecelerating = input.willBeginDecelerating

        return Output(
            viewWillAppear: viewWillAppear,
            viewDidAppear: input.viewDidAppear,
            viewWillDisappear: input.viewWillDisappear,
            prevNextLink: prevNextLink,
            showPostContent: showPostContent,
            showNeedSubscription: showNeedSubscription,
            hideNeedSubscription: hideNeedSubscription,
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
            toastMessage: toastMessage
        )
    }
}
