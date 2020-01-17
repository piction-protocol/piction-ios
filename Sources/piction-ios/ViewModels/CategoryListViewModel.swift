//
//  CategoryListViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/09.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CategoryListViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var items: [CategoryModel] = []

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let categoryList: Driver<[CategoryModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, refreshSession, refreshContent)

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let categoryListAction = Driver.merge(loadPage, loadRetry)
            .map { CategoryAPI.all }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let categoryListSuccess = categoryListAction.elements
            .map { try? $0.map(to: [CategoryModel].self) }
            .flatMap(Driver.from)

        let categoryListError = categoryListAction.error
            .map { _ in Void() }

        let showErrorPopup = categoryListError

        let activityIndicator = categoryListAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            categoryList: categoryListSuccess,
            selectedIndexPath: input.selectedIndexPath,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }

    private func addEmptyItem(categories: [CategoryModel]?) -> [CategoryModel]? {
        guard
            let items = categories,
            items.count % 2 != 0
        else { return categories }

        var itemsWithEmptyItem = items
        itemsWithEmptyItem.append(CategoryModel.from([:])!)
        return itemsWithEmptyItem
    }
}
