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

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

// MARK: - ViewModel
final class ManageSeriesViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let uri: String
    let seriesId: Int?

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, seriesId) = dependency
    }
}

// MARK: - Input & Output
extension ManageSeriesViewModel {
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
        let toastMessage: Driver<String>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension ManageSeriesViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, seriesId) = (self.firebaseManager, self.updater, self.uri, self.seriesId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("시리즈목록_\(uri)_\(seriesId ?? 0)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

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
            .map { _ in LocalizationKey.str_deleted_series.localized() }
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

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            seriesListAction.isExecuting,
            updateSeriesAction.isExecuting,
            deleteSeriesAction.isExecuting)

        // 토스트 메시지
        let toastMessage = Driver.merge(
            updateSeriesSuccess,
            deleteSeriesSuccess,
            reorderItemsSuccess,
            updateSeriesError,
            deleteSeriesError)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            seriesList: seriesList,
            openUpdateSeriesPopup: openUpdateSeriesPopup,
            openDeleteConfirmPopup: openDeleteConfirmPopup,
            selectedIndexPath: input.selectedIndexPath,
            changeEditMode: input.reorderBtnDidTap,
            embedEmptyViewController: embedEmptyView,
            toastMessage: toastMessage,
            activityIndicator: activityIndicator,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
