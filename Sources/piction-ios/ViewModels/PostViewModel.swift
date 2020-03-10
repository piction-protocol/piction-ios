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

// MARK: - ViewModel
final class PostViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String
    var postId: Int = 0

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, postId) = dependency
    }
}
// MARK: - Input & Output
extension PostViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewDidAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
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
        let traitCollectionDidChange: Driver<Void>
        let prevNextLink: Driver<PostLinkModel>
        let showPostContent: Driver<String>
        let showNeedSubscription: Driver<(UserModel, PostModel, SponsorshipModel?)>
        let hideMembershipButton: Driver<Bool>
        let hideNeedSubscription: Driver<Void>
        let headerInfo: Driver<(PostModel, UserModel)>
        let footerInfo: Driver<(String, PostModel)>
        let activityIndicator: Driver<Bool>
        let contentOffset: Driver<CGPoint>
        let willBeginDecelerating: Driver<Void>
        let changeReadmode: Driver<Void>
        let openSignInViewController: Driver<Void>
        let openMembershipListViewController: Driver<(String, Int)>
        let reloadPost: Driver<Void>
        let sharePost: Driver<String>
        let toastMessage: Driver<String>
    }
}

// MARK: - ViewModel Build
extension PostViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri) = (self.firebaseManager, self.updater, self.uri)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("포스트뷰어_\(uri)_\(self.postId)")
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

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 포스트의 컨텐츠 호출
        let postContentAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { PostAPI.getContent(uri: uri, postId: self.postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트의 컨텐츠 호출 성공 시
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

        // 포스트의 컨텐츠 호출 에러 시
        let postContentError = postContentAction.error
            .map { _ in "" }

        // 포스트의 컨텐츠
        let showPostContent = Driver.merge(postContentSuccess, postContentError)

        // 최초 진입 시, 컨텐츠의 내용 갱신 필요 시
        // 이전, 다음 link 호출
        let prevNextLinkAction = Driver.merge(initialLoad, refreshContent)
            .map { PostAPI.getLinks(uri: uri, postId: self.postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 이전, 다음 link 호출 성공 시
        let prevNextLinkSuccess = prevNextLinkAction.elements
            .map { try? $0.map(to: PostLinkModel.self) }
            .flatMap(Driver.from)

        // 이전, 다음 link 호출 에러 시
        let prevNextLinkError = prevNextLinkAction.error
            .map { _ in PostLinkModel.from([:])! }

        // 이전, 다음 link
        let prevNextLink = Driver.merge(prevNextLinkSuccess, prevNextLinkError)

        // 이전 포스트 버튼 눌렀을 때
        let prevPostBtnDidTap = input.prevPostBtnDidTap
            .withLatestFrom(prevNextLinkSuccess)
            .map { $0.previousPost?.id }
            .flatMap(Driver.from)

        // 다음 포스트 버튼 눌렀을 때
        let nextPostBtnDidTap = input.nextPostBtnDidTap
            .withLatestFrom(prevNextLinkSuccess)
            .map { $0.nextPost?.id }
            .flatMap(Driver.from)

        // postId가 변경되어 새로 불러와야 할 때
        let loadPost = input.loadPost

        // postId가 변경되어 새로 불러와야 할 때, 이전 포스트 버튼 눌렀을때, 다음 포스트 버튼 눌렀을 때
        let changePost = Driver.merge(loadPost, prevPostBtnDidTap, nextPostBtnDidTap)
            .do(onNext: { [weak self] postId in
                self?.postId = postId
                updater.refreshContent.onNext(())
            })
            .map { _ in Void() }

        let reloadPost = changePost

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 프로젝트 정보 호출
        let projectInfoAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 정보 호출 성공 시
        let projectInfo = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        // 크리에이터 정보
        let writerInfo = projectInfo
            .map { $0.user }
            .flatMap(Driver.from)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 포스트 정보 호출
        let postItemAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { PostAPI.get(uri: uri, postId: self.postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트 정보 호출 성공 시
        let postItemSuccess = postItemAction.elements
            .map { try? $0.map(to: PostModel.self) }
            .flatMap(Driver.from)

        // 포스트 정보와 크리에이터 정보를 조합하여 헤더 정보로 전달
        let headerInfo = Driver.zip(postItemSuccess, writerInfo)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 유저 정보 호출
        let userInfoAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 유저 정보 호출 에러 시
        let userInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        // 유저 정보
        let userInfo = Driver.merge(userInfoSuccess, userInfoError)

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 구독중인 멤버십 정보 호출
        let subscriptionInfoAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독중인 멤버십 정보 호출 성공 시
        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        // 구독중인 멤버십 정보 호출 에러 시
        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        // 구독중인 멤버십 정보
        let subscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        // 포스트 정보, 구독중인 멤버십 정보, 유저 정보, 크리에이터 정보를 조합하여
        // 구독이 필요한지 확인
        let needSubscription = Driver.zip(postItemSuccess, subscriptionInfo, userInfo, writerInfo)
            .map { (postItem, subscriptionInfo, currentUser, writerInfo) -> Bool in
                if currentUser.loginId ?? "" == writerInfo.loginId ?? "" {
                    return false
                }
                if postItem.membership == nil {
                    return false
                }
                if (postItem.membership?.level != nil) && (subscriptionInfo?.membership?.level == nil) {
                    return true
                }
                if (postItem.membership?.level ?? 0) <= (subscriptionInfo?.membership?.level ?? 0) {
                    return false
                }
                return true
            }

        // 포스트 정보로 footer 정보 전달
        let footerInfo = postItemSuccess
            .map { (uri, $0) }

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시
        // 멤버십 목록 호출
        let membershipListAction = Driver.merge(initialLoad, refreshSession, refreshContent)
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 멤버십 목록 호출 성공 시
        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .flatMap(Driver.from)

        // 유저 정보, 포스트 정보, 구독중인 멤버십 정보를 조합
        let needSubscriptionInfo = Driver.combineLatest(userInfo, postItemSuccess, subscriptionInfo)

        // 구독이 필요하다면 조합된 정보를 전달
        let showNeedSubscription = needSubscription
            .filter { $0 }
            .withLatestFrom(needSubscriptionInfo)

        // activeMembership 이 false인 경우 후원 버튼 숨김
        let hideMembershipButton = Driver.combineLatest(projectInfo, postItemSuccess)
            .map { !($0.activeMembership ?? false) && ($1.membership?.level ?? 0) > 0 }

        // 구독이 필요하지 않다면
        let hideNeedSubscription = needSubscription
            .filter { !$0 }
            .map { _ in Void() }

        // 구독버튼 눌렀을 때
        // 구독 호출
        let freeSubscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(postItemSuccess)
            .filter { ($0.membership?.level ?? 0) == 0 }
            .withLatestFrom(membershipListSuccess)
            .map { $0.filter { ($0.level ?? 0) == 0 }.first?.id ?? 0 }
            .map { MembershipAPI.sponsorship(uri: uri, membershipId: $0, sponsorshipPrice: 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독 호출 성공 시
        let freeSubscriptionSuccess = freeSubscriptionAction.elements
            .map { _ in LocalizationKey.str_project_subscrition_complete.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 구독 호출 에러 시
        let freeSubscriptionError = freeSubscriptionAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 후원이 필요한 경우 후원 버튼 누르면 후원 플랜 목록 화면으로 이동
        let openMembershipListViewController = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(postItemSuccess)
            .filter { ($0.membership?.level ?? 0) > 0 }
            .map { _ in (uri, self.postId) }

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            postItemAction.isExecuting,
            freeSubscriptionAction.isExecuting)

        // 구독, 후원 버튼 눌렀을 때 로그인이 되어 있지 않으면 로그인 화면 출력
        let openSignInViewController = input.subscriptionBtnDidTap
            .withLatestFrom(userInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        // 포스트 공유 버튼 눌렀을 때
        let sharePost = input.shareBarBtnDidTap
            .map { AppInfo.isStaging ? "staging." : "" }
            .map { "https://\($0)piction.network/project/\(uri)/posts/\(self.postId)" }
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                let stagingPath = AppInfo.isStaging ? "staging." : ""
                let url = "https://\(stagingPath)piction.network/project/\(uri)/posts/\(self.postId)"
                return Driver.just(url)
            }

        // offset이 변경되거나 화면이 보여질 때 offset 전달
        let contentOffset = Driver.combineLatest(input.contentOffset, input.viewDidAppear)
            .map { $0.0 }

        // decelerating 일 때
        let willBeginDecelerating = input.willBeginDecelerating

        // 토스트 메시지
        let toastMessage = Driver.merge(
            freeSubscriptionSuccess,
            freeSubscriptionError)

        return Output(
            viewWillAppear: viewWillAppear,
            viewDidAppear: input.viewDidAppear,
            viewWillDisappear: input.viewWillDisappear,
            traitCollectionDidChange: input.traitCollectionDidChange,
            prevNextLink: prevNextLink,
            showPostContent: showPostContent,
            showNeedSubscription: showNeedSubscription,
            hideMembershipButton: hideMembershipButton,
            hideNeedSubscription: hideNeedSubscription,
            headerInfo: headerInfo,
            footerInfo: footerInfo,
            activityIndicator: activityIndicator,
            contentOffset: contentOffset,
            willBeginDecelerating: willBeginDecelerating,
            changeReadmode: input.readmodeBarButton,
            openSignInViewController: openSignInViewController,
            openMembershipListViewController: openMembershipListViewController,
            reloadPost: reloadPost,
            sharePost: sharePost,
            toastMessage: toastMessage
        )
    }
}
