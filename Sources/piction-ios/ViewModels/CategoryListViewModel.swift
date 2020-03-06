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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension CategoryListViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let categoryList: Driver<[CategoryModel]>
        let selectedIndexPath: Driver<IndexPath>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension CategoryListViewModel {
    func build(input: Input) -> Output {

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 세션 갱신 시, 컨텐츠의 내용 갱신 필요 시, 새로고침 필요 시
        // 카테고리 목록 호출
        let categoryListAction = Driver.merge(initialLoad, refreshSession, refreshContent, loadRetry)
            .map { CategoryAPI.all }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 카테고리 목록 호출 성공 시
        let categoryListSuccess = categoryListAction.elements
            .map { try? $0.map(to: [CategoryModel].self) }
            .flatMap(Driver.from)

        // 카테고리 목록 호출 에러 시
        let categoryListError = categoryListAction.error
            .map { _ in Void() }

        // 에러 팝업 출력
        let showErrorPopup = categoryListError

        // 로딩 뷰
        let activityIndicator = categoryListAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
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
