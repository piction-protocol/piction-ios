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
    case seriesHeader(series: SeriesModel)
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
        let updateProject: Driver<Void>
        let seriesList: Driver<Void>
        let subscriptionUser: Driver<Void>
        let deletePost: Driver<(String, Int)>
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
        let openPostViewController: Driver<(String, Int)>
        let openSeriesPostViewController: Driver<(String, Int)>
        let openProjectInfoViewController: Driver<String>
        let openUpdateProjectViewController: Driver<String>
        let openSeriesListViewController: Driver<String>
        let openSubscriptionUserViewController: Driver<String>
        let openFanPassListViewController: Driver<String>
        let activityIndicator: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let updateSelectedProjectMenu = input.changeMenu
            .flatMap { menu -> Driver<Int> in
                return Driver.just(menu)
            }

        let refreshAction = Driver.merge(refreshContent, refreshSession)

        let refreshMenu = refreshAction
            .withLatestFrom(updateSelectedProjectMenu)
            .flatMap { menu -> Driver<Int> in
                return Driver.just(menu)
            }

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                return Driver.just(())
            }

        let loadNextMenu = loadNext
            .withLatestFrom(updateSelectedProjectMenu)

        let selectPostMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 0 }
            .flatMap { [weak self] _ -> Driver<Void> in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
                return Driver.just(())
            }

        let selectSeriesMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 1 }
            .flatMap { [weak self] _ -> Driver<Void> in
                self?.page = 1
                self?.sections = []
                self?.shouldInfiniteScroll = false
                return Driver.just(())
            }

        let subscriptionInfoAction = Driver.merge(updateSelectedProjectMenu, refreshMenu, loadNextMenu)
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

        let openProjectInfoViewController = input.infoBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                return Driver.just(self.uri)
            }

        let loadProjectInfoAction = Driver.merge(selectPostMenu, selectSeriesMenu, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let loadProjectInfoSuccess = loadProjectInfoAction.elements
            .flatMap { response -> Driver<ProjectModel> in
                guard let projectInfo = try? response.map(to: ProjectModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(projectInfo)
            }

        let loadProjectInfoError = loadProjectInfoAction.error
            .flatMap { _ in Driver.just(ProjectModel.from([:])!) }

        let loadProjectInfo = Driver.merge(loadProjectInfoSuccess, loadProjectInfoError)

        let loadSeriesListAction = selectSeriesMenu
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SeriesAPI.all(uri:  self.uri))
                return Action.makeDriver(response)
            }

        let userInfoAction = Driver.merge(viewWillAppear, refreshSession)
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

        let isWriter = Driver.combineLatest(loadProjectInfo, currentUserInfo)
            .flatMap { [weak self] (project, user) -> Driver<Bool> in
                self?.isWriter = project.user?.loginId == user.loginId
                return Driver.just(self?.isWriter ?? false)
            }

        let loadPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .flatMap { [weak self] (_, isWriter) -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                if isWriter {
                    let response = PictionSDK.rx.requestAPI(MyAPI.posts(uri: self.uri, page: self.page + 1, size: 20))
                    return Action.makeDriver(response)
                } else {
                    let response = PictionSDK.rx.requestAPI(PostsAPI.all(uri: self.uri, page: self.page + 1, size: 20))
                    return Action.makeDriver(response)
                }
            }

        let loadPostSuccess = loadPostAction.elements
            .flatMap { response -> Driver<PageViewResponse<PostModel>> in
                guard let pageList = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(pageList)
            }

        let projectSubscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        let loadSuccess = Driver.merge(loadPostAction.elements, loadSeriesListAction.elements)
            .flatMap { _ in Driver.just("") }

        let fanPassListAction = viewWillAppear
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

        let subscriptionInfo = Driver.combineLatest(isWriter, fanPassListSuccess,  projectSubscriptionInfo)

        let subscriptionAction = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 == nil }
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count == 1 }
            .flatMap { [weak self] fanPassList -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.subscription(uri: self?.uri ?? "", fanPassId: fanPassList[safe: 0]?.id ?? 0, subscriptionPrice: fanPassList[safe: 0]?.subscriptionPrice ?? 0))
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

        let openCancelSubscriptionPopup = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 != nil }
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count == 1 }
            .flatMap { _ -> Driver<Void> in
                return Driver.just(())
            }

        let cancelSubscriptionAction = input.cancelSubscriptionBtnDidTap
            .withLatestFrom(projectSubscriptionInfo)
            .filter { $0 != nil }
            .flatMap { [weak self] subscriptionInfo -> Driver<Action<ResponseData>> in
                guard (subscriptionInfo?.fanPass?.level ?? 0) == 0 else { return Driver.empty() }
                guard let fanPassId = subscriptionInfo?.fanPass?.id else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.cancelSubscription(uri: self?.uri ?? "", fanPassId: fanPassId))
                return Action.makeDriver(response)
            }

        let cancelSubscriptionSuccess = cancelSubscriptionAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.str_project_cancel_subscrition.localized())
            }

        let cancelSubscriptionError = cancelSubscriptionAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                return Driver.just(errorMsg.message)
            }

        let openSignInViewController = input.subscriptionBtnDidTap
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId == nil }
            .flatMap { _ in Driver.just(()) }

        let openCreatePostViewController = input.subscriptionBtnDidTap
            .withLatestFrom(isWriter)
            .filter { $0 }
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.uri ?? "")
            }

        let postSection = Driver.zip(loadPostSuccess, projectSubscriptionInfo)
            .flatMap { [weak self] (postList, subscriptionInfo) -> Driver<SectionType<ContentsSection>> in
                guard let `self` = self else { return Driver.empty() }
                if (postList.pageable?.pageNumber ?? 0) >= (postList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                self.page = self.page + 1

                let posts: [ContentsSection] = (postList.content ?? []).map { .postList(post: $0, subscriptionInfo: subscriptionInfo) }

                self.sections.append(contentsOf: posts)

                return Driver.just(SectionType<ContentsSection>.Section(title: "post", items: self.sections))
            }

        let loadSeriesActionSuccess = loadSeriesListAction.elements
            .flatMap { response -> Driver<[SeriesModel]> in
                guard let seriesList = try? response.map(to: [SeriesModel].self) else {
                    return Driver.empty()
                }

                return Driver.just(seriesList)
            }

        let seriesSection = loadSeriesActionSuccess
            .flatMap { [weak self] seriesList -> Driver<SectionType<ContentsSection>> in
                let series: [ContentsSection] = seriesList.map { .seriesList(series: $0) }

                self?.sections = series
                return Driver.just(SectionType<ContentsSection>.Section(title: "series", items: self?.sections ?? []))
            }

        let selectPostItem = input.selectedIndexPath
            .flatMap { [weak self] indexPath -> Driver<(String, Int)> in
                guard let `self` = self else { return Driver.empty() }
                guard self.sections.count > indexPath.row else { return Driver.empty() }

                switch self.sections[indexPath.row] {
                case .postList(let post, _):
                    return Driver.just((self.uri, post.id ?? 0))
                default:
                    return Driver.empty()
                }
            }

        let selectSeriesItem = input.selectedIndexPath
            .flatMap { [weak self] indexPath -> Driver<(String, Int)> in
                guard let `self` = self else { return Driver.empty() }
                guard self.sections.count > indexPath.row else { return Driver.empty() }

                switch self.sections[indexPath.row] {
                case .seriesList(let series):
                    return Driver.just((self.uri, series.id ?? 0))
                default:
                    return Driver.empty()
                }
            }

        let embedPostEmptyView = loadPostSuccess
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if ((items.content?.count ?? 0) == 0) {
                    return Driver.just(.projectPostListEmpty)
                }
                return Driver.empty()
            }

        let embedSeriesEmptyView = loadSeriesActionSuccess
            .flatMap { seriesList -> Driver<CustomEmptyViewStyle> in
                if (seriesList.count == 0) {
                    return Driver.just(.projectSeriesListEmpty)
                }
                return Driver.empty()
        }

        let embedEmptyViewController = Driver.merge(embedPostEmptyView, embedSeriesEmptyView)

        let contentList = Driver.merge(postSection, seriesSection)

        let deletePostAction = input.deletePost
            .flatMap { (uri, postId) -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.delete(uri: uri, postId: postId))
                return Action.makeDriver(response)
            }

        let deletePostSuccess = deletePostAction.elements
            .flatMap { [weak self] _ -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.msg_delete_post_success.localized())
            }

        let deletePostError = deletePostAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                return Driver.just(errorMsg.message)
            }

        let activityIndicator = Driver.merge(
            userInfoAction.isExecuting,
            subscriptionAction.isExecuting,
            cancelSubscriptionAction.isExecuting,
            deletePostAction.isExecuting)

        let showToast = Driver.merge(subscriptionSuccess, cancelSubscriptionSuccess, subscriptionError, cancelSubscriptionError, deletePostSuccess, deletePostSuccess, deletePostError)

        let openUpdateProjectViewController = input.updateProject
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.uri ?? "")
            }

        let openSeriesListViewController = input.seriesList
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.uri ?? "")
            }

        let openSubscriptionUserViewController = input.subscriptionUser
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.uri ?? "")
            }

        let openFanPassListViewController = input.subscriptionBtnDidTap
            .withLatestFrom(fanPassListSuccess)
            .filter { $0.count > 1 }
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.uri ?? "")
            }

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
            openPostViewController: selectPostItem,
            openSeriesPostViewController: selectSeriesItem,
            openProjectInfoViewController: openProjectInfoViewController,
            openUpdateProjectViewController: openUpdateProjectViewController,
            openSeriesListViewController: openSeriesListViewController,
            openSubscriptionUserViewController: openSubscriptionUserViewController,
            openFanPassListViewController: openFanPassListViewController,
            activityIndicator: activityIndicator,
            showToast: showToast
        )
    }
}
