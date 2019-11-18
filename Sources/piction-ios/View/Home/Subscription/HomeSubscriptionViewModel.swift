//
//  HomeSubscriptionViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/15.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

struct HomeSubscriptionModel {
    let project: ProjectModel
    let post: PostModel
}

final class HomeSubscriptionViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let moreBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let openSubscriptionListViewController: Driver<Void>
        let subscriptionList: Driver<[HomeSubscriptionModel]>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let subscriptionProjectListAction = viewWillAppear
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
            .flatMap { response -> Driver<Void> in
                let errorMsg = response as? ErrorType
                switch errorMsg {
                case .unauthorized:
                    return Driver.empty()
                default:
                    return Driver.just(())
                }
            }

        let subscriptionProjectList = subscriptionProjectListSuccess
        let showErrorPopup = subscriptionProjectListError

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

        let subscriptionList = Driver.combineLatest(subscriptionProjectList, subscriptionPostList) { (projects: $0, posts: $1) }
            .flatMap { subscriptions -> Driver<[HomeSubscriptionModel]> in
                var sectionModel: [HomeSubscriptionModel] = []
                let posts = Array(subscriptions.posts.prefix(subscriptions.projects.count))

                for (index, element) in subscriptions.projects.enumerated() {
                    sectionModel.append(HomeSubscriptionModel(project: element, post: posts[index]))
                }
                return Driver.just(sectionModel)
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            openSubscriptionListViewController: input.moreBtnDidTap,
            subscriptionList: subscriptionList,
            showErrorPopup: showErrorPopup
        )
    }
}
