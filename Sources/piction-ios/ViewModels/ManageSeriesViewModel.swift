//
//  ManageSeriesViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ManageSeriesViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int?
    )

    let updater: UpdaterProtocol
    let uri: String
    let seriesId: Int?

    init(dependency: Dependency) {
        (updater, uri, seriesId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let reorderBtnDidTap: Driver<Void>
        let createBtnDidTap: Driver<Void>
        let contextualAction: Driver<(UIContextualAction.Style, IndexPath)>
        let deleteConfirm: Driver<Int>
        let updateSeries: Driver<(Int?, String)>
        let reorderItems: Driver<[Int]>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let seriesList: Driver<[SeriesModel]>
        let openUpdateSeriesPopup: Driver<IndexPath?>
        let openDeleteConfirmPopup: Driver<IndexPath>
        let selectedIndexPath: Driver<IndexPath>
        let changeEditMode: Driver<Void>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showToast: Driver<String>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let seriesListAction = Driver.merge(initialLoad, refreshContent)
            .map { SeriesAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let seriesListSuccess = seriesListAction.elements
            .map { try? $0.map(to: [SeriesModel].self) }
            .flatMap(Driver.from)

        let seriesListError = seriesListAction.error
            .map { _ in [SeriesModel]() }

        let seriesList = Driver.merge(seriesListSuccess, seriesListError)

        let updateSeriesAction = input.updateSeries
            .filter { $0.0 != nil }
            .map { SeriesAPI.update(uri: uri, seriesId: $0.0 ?? 0, name: $0.1) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let createSeriesAction = input.updateSeries
            .filter { $0.0 == nil }
            .map { SeriesAPI.create(uri: uri, name: $0.1) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let updateSeriesSuccess = Driver.merge(updateSeriesAction.elements, createSeriesAction.elements)
            .map { _ in "" }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let updateSeriesError = Driver.merge(updateSeriesAction.error, createSeriesAction.error)
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let createAction = input.createBtnDidTap
            .map { IndexPath?(nil) }

        let editSeriesAction = input.contextualAction
            .filter { $0.0 == .normal }
            .map { $0.1 }
            .flatMap(Driver<IndexPath?>.from)

        let openUpdateSeriesPopup = Driver.merge(createAction, editSeriesAction)

        let openDeleteConfirmPopup = input.contextualAction
            .filter { $0.0 == .destructive }
            .map { $0.1 }
            .flatMap(Driver<IndexPath>.from)

        let deleteSeriesAction = input.deleteConfirm
            .map { SeriesAPI.delete(uri: uri, seriesId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deleteSeriesSuccess = deleteSeriesAction.elements
            .map { _ in LocalizedStrings.str_deleted_series.localized() }
            .do(onNext: { _ in updater.refreshContent.onNext(()) })

        let deleteSeriesError = deleteSeriesAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let embedEmptyView = seriesList
            .filter { $0.isEmpty }
            .map { _ in .searchListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        let reorderItemsAction = input.reorderItems
            .map { SeriesAPI.sort(uri: uri, ids: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let reorderItemsSuccess = reorderItemsAction.elements
            .map { _ in "" }
            .do(onNext: { _ in updater.refreshContent.onNext(()) })

        let activityIndicator = Driver.merge(
            seriesListAction.isExecuting,
            updateSeriesAction.isExecuting,
            deleteSeriesAction.isExecuting)

        let showToast = Driver.merge(
            updateSeriesSuccess,
            deleteSeriesSuccess,
            reorderItemsSuccess,
            updateSeriesError,
            deleteSeriesError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            seriesList: seriesList,
            openUpdateSeriesPopup: openUpdateSeriesPopup,
            openDeleteConfirmPopup: openDeleteConfirmPopup,
            selectedIndexPath: input.selectedIndexPath,
            changeEditMode: input.reorderBtnDidTap,
            embedEmptyViewController: embedEmptyView,
            showToast: showToast,
            activityIndicator: activityIndicator,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
