//
//  ManageSeriesViewModel.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ManageSeriesViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    let updater: UpdaterProtocol
    let uri: String

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let createBtnDidTap: Driver<Void>
        let contextualAction: Driver<(UIContextualAction.Style, IndexPath)>
        let deleteConfirm: Driver<Int>
        let updateSeries: Driver<(String, SeriesModel?)>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let seriesList: Driver<[SeriesModel]>
        let openUpdateSeriesPopup: Driver<IndexPath?>
        let openDeleteConfirmPopup: Driver<IndexPath>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<EmptyViewStyle>
        let showToast: Driver<String>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let seriesListAction = Driver.merge(viewWillAppear, refreshContent)
           .flatMap { _ -> Driver<Action<ResponseData>> in
               let response = PictionSDK.rx.requestAPI(SeriesAPI.all(uri: uri))
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

        let embedEmptyView = seriesList
            .flatMap { items -> Driver<EmptyViewStyle> in
                if (items.count == 0) {
                    return Driver.just(.seriesListEmpty)
                }
                return Driver.empty()
            }

        let showToast = Driver.merge(updateSeriesSuccess, deleteSeriesSuccess)

        return Output(
            viewWillAppear: input.viewWillAppear,
            seriesList: seriesList,
            openUpdateSeriesPopup: openUpdateSeriesPopup,
            openDeleteConfirmPopup: openDeleteConfirmPopup,
            selectedIndexPath: input.selectedIndexPath,
            embedEmptyViewController: embedEmptyView,
            showToast: showToast,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
