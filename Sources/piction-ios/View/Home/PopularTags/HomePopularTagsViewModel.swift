//
//  HomePopularTagsViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/15.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

struct HomePopularTagsModel {
    let tag: TagModel
    let thumbnail: String?
}

final class HomePopularTagsViewModel: ViewModel {

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let moreBtnDidTap: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let popularTags: Driver<[HomePopularTagsModel]>
        let openTagListViewController: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let popularTagListAction = viewWillAppear
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
            .flatMap { _ in Driver.just(()) }

        let popularTagList = popularTagListSuccess
        let showErrorPopup = popularTagListError

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

        let popularTagWithThumbnailList = Driver.combineLatest(popularTagList, popularTagThumbnailList) { (tags: $0, thumbnails: $1) }
            .flatMap { popularTags -> Driver<[HomePopularTagsModel]> in
                var sectionModel: [HomePopularTagsModel] = []
                let thumbnails = Array(popularTags.thumbnails.prefix(popularTags.tags.count))
                for (index, element) in popularTags.tags.enumerated() {
                    sectionModel.append(HomePopularTagsModel(tag: element, thumbnail: thumbnails[safe: index] ?? ""))
                }
                return Driver.just(sectionModel)
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            popularTags: popularTagWithThumbnailList,
            openTagListViewController: input.moreBtnDidTap,
            selectedIndexPath: input.selectedIndexPath,
            showErrorPopup: showErrorPopup
        )
    }
}
