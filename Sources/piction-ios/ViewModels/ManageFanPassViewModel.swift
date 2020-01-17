//
//  ManageFanPassViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ManageFanPassViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int?
    )

    let updater: UpdaterProtocol
    let uri: String
    let fanPassId: Int?

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, uri, fanPassId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let createBtnDidTap: Driver<Void>
        let deleteFanPass: Driver<(String, Int)>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let fanPassList: Driver<[FanPassModel]>
        let selectedIndexPath: Driver<IndexPath>
        let openCreateFanPassViewController: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, loadRetry, refreshContent)

        let fanPassListAction = loadPage
            .map { FanPassAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let fanPassListSuccess = fanPassListAction.elements
            .map { try? $0.map(to: [FanPassModel].self) }
            .flatMap(Driver.from)

        let fanPassListError = fanPassListAction.error
            .map { _ in Void() }

        let openCreateFanPassViewController = input.createBtnDidTap
            .map { uri }

        let deleteAction = input.deleteFanPass
            .map { FanPassAPI.delete(uri: $0, fanPassId: $1) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let deleteSuccess = deleteAction.elements
            .map { _ in LocalizedStrings.msg_delete_fanpass_success.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let deleteError = deleteAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let showErrorPopup = fanPassListError

        let activityIndicator = fanPassListAction.isExecuting

        let dismissViewController = input.closeBtnDidTap

        let showToast = Driver.merge(deleteSuccess, deleteError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            fanPassList: fanPassListSuccess,
            selectedIndexPath: input.selectedIndexPath,
            openCreateFanPassViewController: openCreateFanPassViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            showToast: showToast
        )
    }
}
