//
//  ProjectViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

enum ContentsSection {
    case postCardTypeList(post: PostModel, subscriptionInfo: SponsorshipModel?)
    case postListTypeList(post: PostModel, subscriptionInfo: SponsorshipModel?)
    case seriesPostList(post: PostModel, subscriptionInfo: SponsorshipModel?, number: Int)
    case seriesList(series: SeriesModel)
}

final class ProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String

    var page = 0
    var isWriter: Bool = false
    var shouldInfiniteScroll = true
    var sections: [ContentsSection] = []
    var loadTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let subscriptionBtnDidTap: Driver<Void>
        let cancelSubscriptionBtnDidTap: Driver<Void>
        let membershipBtnDidTap: Driver<Void>
        let changeMenu: Driver<Int>
        let infoBtnDidTap: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let subscriptionUser: Driver<Void>
        let deletePost: Driver<Int>
        let deleteSeries: Driver<Int>
        let updateSeries: Driver<(String, SeriesModel)>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let subscriptionInfo: Driver<(Bool, [MembershipModel], SponsorshipModel?, Bool)>
        let openCancelSubscriptionPopup: Driver<Void>
        let openSignInViewController: Driver<Void>
        let openCreatePostViewController: Driver<String>
        let contentList: Driver<SectionType<ContentsSection>>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let openProjectInfoViewController: Driver<String>
        let openSubscriptionUserViewController: Driver<String>
        let openMembershipListViewController: Driver<String>
        let activityIndicator: Driver<Bool>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri) = (self.firebaseManager, self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("프로젝트_\(uri)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let updateSelectedProjectMenu = input.changeMenu

        let refreshMenu = Driver.merge(refreshContent, refreshSession)
            .withLatestFrom(updateSelectedProjectMenu)

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadNextMenu = loadNext
            .withLatestFrom(updateSelectedProjectMenu)

        let selectPostMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 0 }
            .map { _ in Void() }
            .do(onNext: { [weak self] _ in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        let selectSeriesMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 1 }
            .map { _ in Void() }
            .do(onNext: { [weak self] _ in
                self?.page = 1
                self?.sections = []
                self?.shouldInfiniteScroll = false
            })

        let postSubscriptionInfoAction = Driver.merge(updateSelectedProjectMenu, refreshMenu, loadNextMenu)
            .filter { $0 == 0 }

        let seriesSubscriptionInfoAction = refreshMenu
            .filter { $0 == 1 }

        let subscriptionInfoAction = Driver.merge(postSubscriptionInfoAction, seriesSubscriptionInfoAction)
            .map{ _ in MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        let projectSubscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let openProjectInfoViewController = input.infoBtnDidTap
            .map { uri }

        let loadProjectInfoAction = Driver.merge(selectPostMenu, selectSeriesMenu, loadNext)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadProjectInfoSuccess = loadProjectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let loadProjectInfoError = loadProjectInfoAction.error
            .map { _ in ProjectModel.from([:])! }

        let loadProjectInfo = Driver.merge(loadProjectInfoSuccess, loadProjectInfoError)

        let userInfoAction = Driver.merge(initialLoad, refreshSession)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let currentUserInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let currentUserInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        let isWriter = Driver.combineLatest(loadProjectInfo, currentUserInfo)
            .map { $0.user?.loginId == $1.loginId }
            .do(onNext: { [weak self] isWriter in
                self?.isWriter = isWriter
            })

        let isActiveMembership = loadProjectInfo
            .map { $0.activeMembership }
            .flatMap(Driver.from)

        let loadOthersPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .filter { !$0.1 }
            .map { _ in PostAPI.all(uri: uri, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadWriterPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .filter { $0.1 }
            .map { _ in CreatorAPI.posts(uri: uri, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadPostAction = Driver.merge(loadOthersPostAction, loadWriterPostAction)

        let loadSeriesListAction = selectSeriesMenu
            .map { _ in SeriesAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadPostSuccess = loadPostAction.elements
            .map { try? $0.map(to: PageViewResponse<PostModel>.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] postList in
                guard
                    let page = self?.page,
                    let pageNumber = postList.pageable?.pageNumber,
                    let totalPages = postList.totalPages
                else { return }

                self?.shouldInfiniteScroll = pageNumber < totalPages - 1
                self?.page = page + 1
            })

        let membershipListAction = initialLoad
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .flatMap(Driver.from)

        let subscriptionInfo = Driver.combineLatest(isWriter, membershipListSuccess, projectSubscriptionInfo, isActiveMembership)

        let subscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 == nil }
            .withLatestFrom(membershipListSuccess)
            .filter { $0.count == 1 }
            .map { MembershipAPI.sponsorship(uri: uri, membershipId: $0[safe: 0]?.id ?? 0, price: $0[safe: 0]?.price ?? 0) }
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
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 != nil }
            .withLatestFrom(membershipListSuccess)
            .filter { $0.count == 1 }
            .map { _ in Void() }

        let cancelSubscriptionAction = input.cancelSubscriptionBtnDidTap
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 != nil }
            .filter { ($0?.membership?.level ?? 0) == 0 }
            .map { MembershipAPI.cancelSponsorship(uri: uri, membershipId: $0?.membership?.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let cancelSubscriptionSuccess = cancelSubscriptionAction.elements
            .map { _ in LocalizationKey.str_project_cancel_subscrition.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })
 
        let cancelSubscriptionError = cancelSubscriptionAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let openSignInViewController = input.subscriptionBtnDidTap
            .withLatestFrom(membershipListSuccess)
            .filter { $0.count == 1 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let openCreatePostViewController = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { $0 }
            .map { _ in uri }

        let postCardTypeSection = loadPostSuccess
            .withLatestFrom(loadProjectInfo) { ($0, $1) }
            .filter { $1.viewType == "CARD" }
            .withLatestFrom(projectSubscriptionInfo) { ($0.0, $1) }
            .map { (postList, subscriptionInfo) in (postList.content ?? []).map { .postCardTypeList(post: $0, subscriptionInfo: subscriptionInfo) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        let postListTypeSection = loadPostSuccess
            .withLatestFrom(loadProjectInfo) { ($0, $1) }
            .filter { $1.viewType == "LIST" }
            .withLatestFrom(projectSubscriptionInfo) { ($0.0, $1) }
            .map { (postList, subscriptionInfo) in (postList.content ?? []).map { .postListTypeList(post: $0, subscriptionInfo: subscriptionInfo) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        let loadSeriesSuccess = loadSeriesListAction.elements
            .map { try? $0.map(to: [SeriesModel].self) }
            .flatMap(Driver.from)
            .map { $0.filter { ($0.postCount ?? 0) > 0 } }

        let seriesSection = loadSeriesSuccess
            .map { $0.map { .seriesList(series: $0) } }
            .map { self.sections = $0 }
            .map { SectionType<ContentsSection>.Section(title: "series", items: self.sections) }

        let embedPostEmptyView = loadPostSuccess
            .map { $0.content?.isEmpty }
            .map { _ in .projectPostListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let embedSeriesEmptyView = loadSeriesSuccess
            .filter { $0.isEmpty }
            .map { _ in .projectSeriesListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let embedEmptyViewController = Driver.merge(embedPostEmptyView, embedSeriesEmptyView)

        let contentList = Driver.merge(postCardTypeSection, postListTypeSection, seriesSection)

        let deletePostAction = input.deletePost
            .map { PostAPI.delete(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deletePostSuccess = deletePostAction.elements
            .map { _ in LocalizationKey.msg_delete_post_success.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let deletePostError = deletePostAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let deleteSeriesAction = input.deleteSeries
            .map { SeriesAPI.delete(uri: uri, seriesId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deleteSeriesSuccess = deleteSeriesAction.elements
            .map { _ in LocalizationKey.str_deleted_series.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let deleteSeriesError = deleteSeriesAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let updateSeriesAction = input.updateSeries
            .map { SeriesAPI.update(uri: uri, seriesId: $0.1.id ?? 0, name: $0.0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let updateSeriesSuccess = updateSeriesAction.elements
            .map { _ in "" }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let updateSeriesError = updateSeriesAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let activityIndicator = Driver.merge(
            userInfoAction.isExecuting,
            subscriptionAction.isExecuting,
            cancelSubscriptionAction.isExecuting,
            deletePostAction.isExecuting,
            deleteSeriesAction.isExecuting,
            updateSeriesAction.isExecuting)

        let toastMessage = Driver.merge(subscriptionSuccess, cancelSubscriptionSuccess, subscriptionError, cancelSubscriptionError, deletePostSuccess, deleteSeriesSuccess, updateSeriesSuccess, deletePostError, deleteSeriesError, updateSeriesError)

        let openSubscriptionUserViewController = input.subscriptionUser
            .map { _ in uri }
            .flatMap(Driver<String>.from)

        let openMembershipListViewController = input.membershipBtnDidTap
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .map { _ in uri }
            .flatMap(Driver<String>.from)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            projectInfo: loadProjectInfo,
            subscriptionInfo: subscriptionInfo,
            openCancelSubscriptionPopup: openCancelSubscriptionPopup,
            openSignInViewController: openSignInViewController,
            openCreatePostViewController: openCreatePostViewController,
            contentList: contentList,
            embedEmptyViewController: embedEmptyViewController,
            selectedIndexPath: input.selectedIndexPath,
            openProjectInfoViewController: openProjectInfoViewController,
            openSubscriptionUserViewController: openSubscriptionUserViewController,
            openMembershipListViewController: openMembershipListViewController,
            activityIndicator: activityIndicator,
            toastMessage: toastMessage
        )
    }
}
