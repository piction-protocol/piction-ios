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

        let subscriptionPost1Action = subscriptionProjectList
            .flatMap { list -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.all(uri: list[safe: 0]?.uri ?? "", isRequiredFanPass: true, page: 1, size: 1))
                return Action.makeDriver(response)
            }

        let subscriptionPost1Success = subscriptionPost1Action.elements
            .flatMap { response -> Driver<PostModel> in
                guard let posts = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(posts.content?.first ?? PostModel.from([:])!)
            }

        let subscriptionPost1Error = subscriptionPost1Action.error
            .flatMap { _ in Driver.just(PostModel.from([:])!) }

        let subscriptionPost1Item = Driver.merge(subscriptionPost1Success, subscriptionPost1Error)

        let subscriptionPost2Action = subscriptionProjectList
            .flatMap { list -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.all(uri: list[safe: 1]?.uri ?? "", isRequiredFanPass: true, page: 1, size: 1))
                return Action.makeDriver(response)
            }

        let subscriptionPost2Success = subscriptionPost2Action.elements
            .flatMap { response -> Driver<PostModel> in
                guard let posts = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(posts.content?.first ?? PostModel.from([:])!)
            }

        let subscriptionPost2Error = subscriptionPost2Action.error
            .flatMap { _ in Driver.just(PostModel.from([:])!) }

        let subscriptionPost2Item = Driver.merge(subscriptionPost2Success, subscriptionPost2Error)

        let subscriptionPost3Action = subscriptionProjectList
            .flatMap { list -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.all(uri: list[safe: 2]?.uri ?? "", isRequiredFanPass: true, page: 1, size: 1))
                return Action.makeDriver(response)
            }

        let subscriptionPost3Success = subscriptionPost3Action.elements
            .flatMap { response -> Driver<PostModel> in
                guard let posts = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(posts.content?.first ?? PostModel.from([:])!)
            }

        let subscriptionPost3Error = subscriptionPost3Action.error
            .flatMap { _ in Driver.just(PostModel.from([:])!) }

        let subscriptionPost3Item = Driver.merge(subscriptionPost3Success, subscriptionPost3Error)

        let subscriptionPost4Action = subscriptionProjectList
            .flatMap { list -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(PostsAPI.all(uri: list[safe: 3]?.uri ?? "", isRequiredFanPass: true, page: 1, size: 1))
                return Action.makeDriver(response)
            }

        let subscriptionPost4Success = subscriptionPost4Action.elements
            .flatMap { response -> Driver<PostModel> in
                guard let posts = try? response.map(to: PageViewResponse<PostModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(posts.content?.first ?? PostModel.from([:])!)
            }

        let subscriptionPost4Error = subscriptionPost4Action.error
            .flatMap { _ in Driver.just(PostModel.from([:])!) }

        let subscriptionPost4Item = Driver.merge(subscriptionPost4Success, subscriptionPost4Error)

        let subscriptionPostList = Driver.combineLatest(subscriptionPost1Item, subscriptionPost2Item, subscriptionPost3Item, subscriptionPost4Item)
            .flatMap { (post1, post2, post3, post4) -> Driver<[PostModel]> in
                let postList: [PostModel] = [post1, post2, post3, post4]
                return Driver.just(postList)
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

        let popularTagThumbnail1Action = popularTagList
            .flatMap { tag -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.all(page: 1, size: 1, tagName: tag[safe: 0]?.name ?? ""))
                return Action.makeDriver(response)
            }

        let popularTagThumbnail1Success = popularTagThumbnail1Action.elements
            .flatMap { response -> Driver<String> in
                guard let projects = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(projects.content?.first?.thumbnail ?? "")
            }

        let popularTagThumbnail1Error = popularTagThumbnail1Action.error
            .flatMap { _ in Driver.just("") }

        let popularTagThumbnail1Item = Driver.merge(popularTagThumbnail1Success, popularTagThumbnail1Error)

        let popularTagThumbnail2Action = popularTagList
            .flatMap { tag -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.all(page: 1, size: 1, tagName: tag[safe: 1]?.name ?? ""))
                return Action.makeDriver(response)
            }

        let popularTagThumbnail2Success = popularTagThumbnail2Action.elements
            .flatMap { response -> Driver<String> in
                guard let projects = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(projects.content?.first?.thumbnail ?? "")
            }

        let popularTagThumbnail2Error = popularTagThumbnail2Action.error
            .flatMap { _ in Driver.just("") }

        let popularTagThumbnail2Item = Driver.merge(popularTagThumbnail2Success, popularTagThumbnail2Error)

        let popularTagThumbnail3Action = popularTagList
            .flatMap { tag -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.all(page: 1, size: 1, tagName: tag[safe: 2]?.name ?? ""))
                return Action.makeDriver(response)
            }

        let popularTagThumbnail3Success = popularTagThumbnail3Action.elements
            .flatMap { response -> Driver<String> in
                guard let projects = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(projects.content?.first?.thumbnail ?? "")
            }

        let popularTagThumbnail3Error = popularTagThumbnail3Action.error
            .flatMap { _ in Driver.just("") }

        let popularTagThumbnail3Item = Driver.merge(popularTagThumbnail3Success, popularTagThumbnail3Error)

        let popularTagThumbnail4Action = popularTagList
            .flatMap { tag -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.all(page: 1, size: 1, tagName: tag[safe: 3]?.name ?? ""))
                return Action.makeDriver(response)
            }

        let popularTagThumbnail4Success = popularTagThumbnail4Action.elements
            .flatMap { response -> Driver<String> in
                guard let projects = try? response.map(to: PageViewResponse<ProjectModel>.self) else {
                    return Driver.empty()
                }
                return Driver.just(projects.content?.first?.thumbnail ?? "")
            }

        let popularTagThumbnail4Error = popularTagThumbnail4Action.error
            .flatMap { _ in Driver.just("") }

        let popularTagThumbnail4Item = Driver.merge(popularTagThumbnail4Success, popularTagThumbnail4Error)

        let popularTagThumbnailList = Driver.combineLatest(popularTagThumbnail1Item, popularTagThumbnail2Item, popularTagThumbnail3Item, popularTagThumbnail4Item)
            .flatMap { (thumbnail1, thumbnail2, thumbnail3, thumbnail4) -> Driver<[String]> in
                let thumbnailList: [String] = [thumbnail1, thumbnail2, thumbnail3, thumbnail4]
                return Driver.just(thumbnailList)
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
