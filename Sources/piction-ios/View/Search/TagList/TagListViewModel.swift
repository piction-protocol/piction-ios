//
//  TagListViewModel.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class TagListViewModel: ViewModel {

    init() {}

    var loadRetryTrigger = PublishSubject<Void>()

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let tagList: Driver<[TagModel]>
        let openTagResultProjectViewController: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let tagListAction = Driver.merge(viewWillAppear, loadRetry)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(TagsAPI.popularAll)
                return Action.makeDriver(response)
            }

        let tagListSuccess = tagListAction.elements
            .flatMap { response -> Driver<[TagModel]> in
                guard let tagList = try? response.map(to: [TagModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(tagList)
            }

        let tagListError = tagListAction.error
            .flatMap { _ in Driver.just(()) }

        let embedEmptyView = tagListSuccess
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.searchListEmpty)
                }
                return Driver.empty()
            }

        let activityIndicator = tagListAction.isExecuting

        let showErrorPopup = tagListError

        return Output(
            viewWillAppear: viewWillAppear,
            tagList: tagListSuccess,
            openTagResultProjectViewController: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
