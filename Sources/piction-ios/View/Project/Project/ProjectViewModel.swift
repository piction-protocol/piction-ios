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
    case postList(post: PostModel, subscriptionInfo: SubscriptionModel?)
    case seriesPostList(post: PostModel, isSubscribing: Bool, number: Int)
    case seriesList(series: SeriesModel)
}

final class ProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    let updater: UpdaterProtocol
    let uri: String

    var page = 0
    var isWriter: Bool = false
    var shouldInfiniteScroll = true
    var sections: [ContentsSection] = []
    var loadTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let subscriptionBtnDidTap: Driver<Void>
        let cancelSubscriptionBtnDidTap: Driver<Void>
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
        let subscriptionInfo: Driver<(Bool, [FanPassModel], SubscriptionModel?)>
        let openCancelSubscriptionPopup: Driver<Void>
        let openSignInViewController: Driver<Void>
        let openCreatePostViewController: Driver<String>
        let contentList: Driver<SectionType<ContentsSection>>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let openProjectInfoViewController: Driver<String>
        let openSubscriptionUserViewController: Driver<String>
        let openFanPassListViewController: Driver<String>
        let activityIndicator: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

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
            .map{ _ in ProjectsAPI.getProjectSubscription(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SubscriptionModel.self) }
            .flatMap(Driver<SubscriptionModel?>.from)

        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SubscriptionModel?(nil) }

        let projectSubscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let openProjectInfoViewController = input.infoBtnDidTap
            .map { uri }

        let loadProjectInfoAction = Driver.merge(selectPostMenu, selectSeriesMenu, loadNext)
            .map { ProjectsAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadProjectInfoSuccess = loadProjectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let loadProjectInfoError = loadProjectInfoAction.error
            .map { _ in ProjectModel.from([:])! }

        let loadProjectInfo = Driver.merge(loadProjectInfoSuccess, loadProjectInfoError)

        let userInfoAction = Driver.merge(viewWillAppear, refreshSession)
            .map { UsersAPI.me }
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

        let loadOthersPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .filter { !$0.1 }
            .map { _ in PostsAPI.all(uri: uri, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadWriterPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .filter { $0.1 }
            .map { _ in MyAPI.posts(uri: uri, page: self.page + 1, size: 20) }
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

        let fanPassListAction = viewWillAppear
            .map { ProjectsAPI.fanPassAll(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let fanPassListSuccess = fanPassListAction.elements
            .map { try? $0.map(to: [FanPassModel].self) }
            .flatMap(Driver.from)

        let subscriptionInfo = Driver.combineLatest(isWriter, fanPassListSuccess, projectSubscriptionInfo)

        let subscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 == nil }
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count == 1 }
            .map { ProjectsAPI.subscription(uri: uri, fanPassId: $0[safe: 0]?.id ?? 0, subscriptionPrice: $0[safe: 0]?.subscriptionPrice ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let subscriptionSuccess = subscriptionAction.elements
            .map { _ in LocalizedStrings.str_project_subscrition_complete.localized() }
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
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count == 1 }
            .map { _ in Void() }

        let cancelSubscriptionAction = input.cancelSubscriptionBtnDidTap
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 != nil }
            .filter { ($0?.fanPass?.level ?? 0) == 0 }
            .map { ProjectsAPI.cancelSubscription(uri: uri, fanPassId: $0?.fanPass?.id ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let cancelSubscriptionSuccess = cancelSubscriptionAction.elements
            .map { _ in LocalizedStrings.str_project_cancel_subscrition.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })
 
        let cancelSubscriptionError = cancelSubscriptionAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let openSignInViewController = input.subscriptionBtnDidTap
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count == 1 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .map { _ in Void() }

        let openCreatePostViewController = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { $0 }
            .map { _ in uri }

        let postSection = loadPostSuccess
            .withLatestFrom(projectSubscriptionInfo) { ($0, $1) }
            .map { (postList, subscriptionInfo) in (postList.content ?? []).map { .postList(post: $0, subscriptionInfo: subscriptionInfo) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        let loadSeriesSuccess = loadSeriesListAction.elements
            .map { try? $0.map(to: [SeriesModel].self) }
            .flatMap(Driver.from)

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

        let contentList = Driver.merge(postSection, seriesSection)

        let deletePostAction = input.deletePost
            .map { PostsAPI.delete(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deletePostSuccess = deletePostAction.elements
            .map { _ in LocalizedStrings.msg_delete_post_success.localized() }
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
            .map { _ in LocalizedStrings.str_deleted_series.localized() }
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

        let showToast = Driver.merge(subscriptionSuccess, cancelSubscriptionSuccess, subscriptionError, cancelSubscriptionError, deletePostSuccess, deleteSeriesSuccess, updateSeriesSuccess, deletePostError, deleteSeriesError, updateSeriesError)

        let openSubscriptionUserViewController = input.subscriptionUser
            .map { _ in uri }
            .flatMap(Driver<String>.from)

        let openFanPassListViewController = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count > 1 }
            .map { _ in uri }
            .flatMap(Driver<String>.from)

        return Output(
            viewWillAppear: input.viewWillAppear,
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
            openFanPassListViewController: openFanPassListViewController,
            activityIndicator: activityIndicator,
            showToast: showToast
        )
    }
}
