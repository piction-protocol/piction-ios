//
//  HomeViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class HomeViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var loadTrigger = PublishSubject<Void>()

    var popularTagThumbnail = PublishSubject<String>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let sectionList: Driver<HomeBySection>
        let openErrorPopup: Driver<Void>
        let isFetching: Driver<Bool>
    }

    func build(input: Input) -> Output {
        var disposeBag = DisposeBag()

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let trendingListAction = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, loadTrigger.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.trending)
                return Action.makeDriver(response)
            }

        let trendingListSuccess = trendingListAction.elements
            .flatMap { response -> Driver<[ProjectModel]> in
                guard let projectList = try? response.map(to: [ProjectModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(projectList)
            }

        let trendingListError = trendingListAction.error
            .flatMap { _ -> Driver<[ProjectModel]> in
                return Driver.just([])
            }

        let trendingList = Driver.merge(trendingListSuccess, trendingListError)

        let subscriptionProjectListAction = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, refreshSession, refreshContent, loadTrigger.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.subscription(page: 1, size: 4))
                return Action.makeDriver(response)
            }

        let subscriptionProjectListSuccess = subscriptionProjectListAction.elements
            .flatMap { response -> Driver<[ProjectModel]> in
                guard let popularTagList = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(popularTagList.content ?? [])
            }

        let subscriptionProjectListError = subscriptionProjectListAction.error
            .flatMap { _ -> Driver<[ProjectModel]> in
                return Driver.just([])
            }

        let subscriptionProjectList = Driver.merge(subscriptionProjectListSuccess, subscriptionProjectListError)

        let subscriptionPostAction = subscriptionProjectList
            .flatMap { projects -> Driver<[Action<ResponseData>]> in
                var responses: [Driver<Action<ResponseData>>] = []
                for project in projects {
                    guard let uri = project.uri else { return Driver.empty() }
                    let response = Action.makeDriver(PictionSDK.rx.requestAPI(PostsAPI.all(uri: uri, page: 1, size: 1)))
                    responses.append(response)
                }
                return Driver.zip(responses)
            }

        let subscriptionPostList = subscriptionPostAction
            .flatMap { responses -> Driver<[PostModel]> in
                var posts: [PostModel] = []
                for (index, element) in responses.enumerated() {
                    switch element {
                    case .succeeded(let response):
                        guard let pageList = try? response.map(to: PageViewResponse<PostModel>.self) else {
                            return Driver.empty()
                        }
                        posts.append(pageList.content?.first ?? PostModel.from([:])!)

                        if index >= responses.count - 1 {
                            return Driver.just(posts)
                        }
                    default:
                        return Driver.empty()
                    }
                }
                return Driver.empty()
            }

        let subscriptionList = Driver.combineLatest(subscriptionProjectList, subscriptionPostList)

        let popularTagListAction = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, loadTrigger.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(TagsAPI.popular)
                return Action.makeDriver(response)
            }

        let popularTagListSuccess = popularTagListAction.elements
            .flatMap { response -> Driver<[TagModel]> in
                guard let popularTagList = try? response.map(to: [TagModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(popularTagList)
            }

        let popularTagListError = popularTagListAction.error
            .flatMap { _ -> Driver<[TagModel]> in
                return Driver.just([])
            }

        let popularTagList = Driver.merge(popularTagListSuccess, popularTagListError)

        let popularTagThumbnailAction = popularTagList
            .flatMap { tags -> Driver<[Action<ResponseData>]> in
                var responses: [Driver<Action<ResponseData>>] = []
                for tag in tags {
                    guard let tagname = tag.name else { return Driver.empty() }
                    let response = Action.makeDriver(PictionSDK.rx.requestAPI(ProjectsAPI.all(page: 1, size: 1, tagName: tagname)))
                    responses.append(response)
                }
                return Driver.zip(responses)
            }

        let popularTagThumbnailList = popularTagThumbnailAction
            .flatMap { responses -> Driver<[String]> in
                var thumbnails: [String] = []
                for (index, element) in responses.enumerated() {
                    switch element {
                    case .succeeded(let response):
                        guard let pageList = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                            return Driver.empty()
                        }
                        thumbnails.append(pageList.content?.first?.thumbnail ?? "")

                        if index >= responses.count - 1 {
                            return Driver.just(thumbnails)
                        }
                    default:
                        return Driver.empty()
                    }
                }
                return Driver.empty()
            }

        let popularTagWithThumbnailList = Driver.combineLatest(popularTagList, popularTagThumbnailList)
            .do(onNext: { _ in
                print("ok")
            })

        let noticeListAction = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, refreshSession, loadTrigger.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(BannersAPI.all)
                return Action.makeDriver(response)
            }

        let noticeListSuccess = noticeListAction.elements
            .flatMap { response -> Driver<[BannerModel]> in
                guard let noticeList = try? response.map(to: [BannerModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(noticeList)
            }

        let noticeListError = noticeListAction.error
            .flatMap { _ -> Driver<[BannerModel]> in
                return Driver.just([])
            }

        let noticeList = Driver.merge(noticeListSuccess, noticeListError)

        let sectionList = Driver.combineLatest(trendingList, subscriptionList, popularTagWithThumbnailList, noticeList)
            .flatMap { (trending, subscriptions, popularTags, notices) -> Driver<HomeBySection> in

                var section: [HomeItemType] = []

                if trending.count > 0 {
                    section.append(.header(model: .trending))
                    section.append(.trending(model: trending))
                }
                if subscriptions.0.count > 0 {
                    section.append(.header(model: .subscription))
                    section.append(.subscription(projects: subscriptions.0, posts: Array(subscriptions.1.prefix(subscriptions.0.count))))
                }
                if popularTags.0.count > 0 {
                    section.append(.header(model: .popularTag))
                    section.append(.popularTag(tags: popularTags.0, thumbnails: Array(popularTags.1.prefix(popularTags.0.count))))
                }
                if notices.count > 0 {
                    section.append(.header(model: .notice))
                    section.append(.notice(model: notices))
                }
                return Driver.just(HomeBySection.Section(title: "home", items: section))
            }

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(sectionList)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let openErrorPopup = Driver.zip(trendingListAction.error, popularTagListAction.error)
            .flatMap { _ -> Driver<Void> in
                return Driver.just(())
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            sectionList: sectionList,
            openErrorPopup: openErrorPopup,
            isFetching: refreshAction.isExecuting
        )
    }
}
