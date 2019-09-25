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
import RxPictionSDK

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
    var sections: [ContentsItemType] = []
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
        let contentOffset: Driver<CGPoint>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let projectInfo: Driver<ProjectModel>
        let subscriptionInfo: Driver<(Bool, Bool)>
        let openCancelSubscriptionPopup: Driver<Void>
        let openSignInViewController: Driver<Void>
        let openCreatePostViewController: Driver<String>
        let contentList: Driver<ContentsBySection>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let openPostViewController: Driver<(String, Int)>
        let openSeriesPostViewController: Driver<(String, Int)>
        let openProjectInfoViewController: Driver<String>
        let contentOffset: Driver<CGPoint>
        let activityIndicator: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear
        let viewWillDisappear = input.viewWillDisappear
        let contentOffset = input.contentOffset

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
                self.page = self.page + 1
                return Driver.just(())
            }

        let loadNextMenu = loadNext
            .withLatestFrom(updateSelectedProjectMenu)

        let selectPostMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 0 }
            .flatMap { [weak self] _ -> Driver<Void> in
                self?.page = 1
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

        let isSubscribingAction = Driver.merge(updateSelectedProjectMenu, refreshMenu, loadNextMenu)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(FanPassAPI.isSubscription(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let isSubscribingSuccess = isSubscribingAction.elements
            .flatMap { response -> Driver<Bool> in
                guard let isSubscribing = try? response.map(to: SubscriptionModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(isSubscribing.fanPass != nil)
            }

        let isSubscribingError = isSubscribingAction.error
            .flatMap { _ in Driver.just(false) }

        let loadPostAction = Driver.merge(selectPostMenu, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.all(uri: self.uri, isRequiredFanPass: nil, page: self.page, size: 10))
                return Action.makeDriver(response)
            }

        let loadPostSuccess = loadPostAction.elements
            .flatMap { response -> Driver<PageViewResponse<PostModel>> in
                guard let pageList = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(pageList)
            }

        let loadProjectInfoAction = Driver.merge(selectPostMenu, selectSeriesMenu, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let openProjectInfoViewController = input.infoBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                return Driver.just(self.uri)
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

        let userInfoAction = Driver.merge(selectPostMenu, selectSeriesMenu, loadNext)
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

        let isSubscribingForInfo = Driver.merge(isSubscribingSuccess, isSubscribingError)

        let isSubscribing = isSubscribingForInfo
            .withLatestFrom(updateSelectedProjectMenu)
            .filter { $0 == 0 }
            .withLatestFrom(isSubscribingForInfo)

        let subscriptionInfo = Driver.combineLatest(isWriter, isSubscribingForInfo)

        let fanPassListAction = Driver.merge(viewWillAppear)
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
            .withLatestFrom(isWriter)
            .filter { !$0 }
            .withLatestFrom(currentUserInfo)
            .filter { $0.loginId != nil }
            .withLatestFrom(isSubscribingSuccess)
            .filter { !$0 }
            .withLatestFrom(fanPassListSuccess)
            .flatMap { fanPassList -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(FanPassAPI.subscription(fanPassId: fanPassList[safe: 0]?.id ?? 0, subscriptionPrice: fanPassList[safe: 0]?.subscriptionPrice ?? 0))
                return Action.makeDriver(response)
            }

        let subscriptionSuccess = subscriptionAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just("구독 완료")
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
            .withLatestFrom(isSubscribingSuccess)
            .filter { $0 }
            .flatMap { _ -> Driver<Void> in
                return Driver.just(())
            }

        let cancelSubscriptionAction = input.cancelSubscriptionBtnDidTap
            .withLatestFrom(fanPassListSuccess)
            .flatMap { fanPassList -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(FanPassAPI.delete(fanPassId: fanPassList[safe: 0]?.id ?? 0))
                return Action.makeDriver(response)
            }

        let cancelSubscriptionSuccess = cancelSubscriptionAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just("구독이 취소되었습니다.")
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

        let postSection = Driver.zip(loadPostSuccess, isSubscribing)
            .flatMap { [weak self] (postList, isSubscribing) -> Driver<ContentsBySection> in

                if (postList.pageable?.pageNumber ?? 0) >= (postList.totalPages ?? 0) - 1 {
                    self?.shouldInfiniteScroll = false
                }

                let posts: [ContentsItemType] = (postList.content ?? []).map { .postList(post: $0, isSubscribing: isSubscribing) }

                self?.sections.append(contentsOf: posts)

                return Driver.just(ContentsBySection.Section(title: "post", items: self?.sections ?? []))
            }

        let loadSeriesActionSuccess = loadSeriesListAction.elements
            .flatMap { response -> Driver<[SeriesModel]> in
                guard let seriesList = try? response.map(to: [SeriesModel].self) else {
                    return Driver.empty()
                }

                return Driver.just(seriesList)
            }

        let seriesSection = loadSeriesActionSuccess
            .flatMap { [weak self] seriesList -> Driver<ContentsBySection> in
                let series: [ContentsItemType] = seriesList.map { .seriesList(series: $0) }

                self?.sections = series
                return Driver.just(ContentsBySection.Section(title: "series", items: self?.sections ?? []))
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

        let showActivityIndicator = Driver.merge(subscriptionAction, cancelSubscriptionAction)
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = Driver.merge(subscriptionSuccess, subscriptionError, cancelSubscriptionSuccess, cancelSubscriptionError)
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)
            .flatMap { status in Driver.just(status) }

        let showToast = Driver.merge(subscriptionSuccess, cancelSubscriptionSuccess, subscriptionError, cancelSubscriptionError)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
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
            contentOffset: contentOffset,
            activityIndicator: activityIndicator,
            showToast: showToast
        )
    }
}
