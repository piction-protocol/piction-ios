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
        let updateSeries: Driver<(String, SeriesModel?)>
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
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let seriesListAction = Driver.merge(viewWillAppear, refreshContent)
               .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                    let response = PictionSDK.rx.requestAPI(SeriesAPI.all(uri: self?.uri ?? ""))
                   return Action.makeDriver(response)
               }

        let seriesListSuccess = seriesListAction.elements
           .flatMap { response -> Driver<[SeriesModel]> in
               guard let seriesList = try? response.map(to: [SeriesModel].self) else {
                   return Driver.empty()
               }
               return Driver.just(seriesList)
           }

        let seriesListError = seriesListAction.error
            .flatMap { _ in Driver.just([SeriesModel.from([:])!]) }

        let seriesList = Driver.merge(seriesListSuccess, seriesListError)

        let createSeriesAction = input.createBtnDidTap
            .flatMap { _ -> Driver<IndexPath?> in
                return Driver.just(nil)
            }

        let updateSeriesAction = input.updateSeries
            .flatMap { [weak self] (name, series) -> Driver<Action<ResponseData>> in
                if series == nil {
                    let response = PictionSDK.rx.requestAPI(SeriesAPI.create(uri: self?.uri ?? "", name: name))
                    return Action.makeDriver(response)
                } else {
                    let response = PictionSDK.rx.requestAPI(SeriesAPI.update(uri: self?.uri ?? "", seriesId: series?.id ?? 0, name: name))
                    return Action.makeDriver(response)
                }
            }

        let updateSeriesSuccess = updateSeriesAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let _ = try? response.map(to: SeriesModel.self) else {
                    return Driver.empty()
                }
                self?.updater.refreshContent.onNext(())
                return Driver.just("")
            }

        let updateSeriesError = updateSeriesAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let editSeriesAction = input.contextualAction
            .filter { $0.0 == .normal }
            .flatMap { (_, indexPath) -> Driver<IndexPath?> in
                return Driver.just(indexPath)
            }

        let openUpdateSeriesPopup = Driver.merge(createSeriesAction, editSeriesAction)

        let openDeleteConfirmPopup = input.contextualAction
            .filter { $0.0 == .destructive }
            .flatMap { (_, indexPath) -> Driver<IndexPath> in
                return Driver.just(indexPath)
            }

        let deleteSeriesAction = input.deleteConfirm
            .flatMap { [weak self] seriesId -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SeriesAPI.delete(uri: self?.uri ?? "", seriesId: seriesId))
                return Action.makeDriver(response)
            }

        let deleteSeriesSuccess = deleteSeriesAction.elements
            .flatMap { [weak self] _ -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.str_deleted_series.localized())
            }

        let deleteSeriesError = deleteSeriesAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let embedEmptyView = seriesList
            .flatMap { items -> Driver<CustomEmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.searchListEmpty)
                }
                return Driver.empty()
            }

        let reorderItemsAction = input.reorderItems
            .flatMap { [weak self] ids -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SeriesAPI.sort(uri: self?.uri ?? "", ids: ids))
                return Action.makeDriver(response)
            }

        let reorderItemsSuccess = reorderItemsAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let _ = try? response.map(to: [SeriesModel].self) else {
                    return Driver.empty()
                }
                self?.updater.refreshContent.onNext(())
                return Driver.just("")
            }

        let activityIndicator = Driver.merge(
            seriesListAction.isExecuting,
            updateSeriesAction.isExecuting,
            deleteSeriesAction.isExecuting)

        let showToast = Driver.merge(updateSeriesSuccess, deleteSeriesSuccess, reorderItemsSuccess, updateSeriesError, deleteSeriesError)

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
