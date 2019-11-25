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

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, loadRetry, refreshContent)

        let fanPassListAction = initialLoad
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.fanPassAll(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let fanPassListSuccess = fanPassListAction.elements
            .flatMap { response -> Driver<[FanPassModel]> in
                guard let fanPassList = try? response.map(to: [FanPassModel].self) else { return Driver.empty() }
                return Driver.just(fanPassList)
            }

        let fanPassListError = fanPassListAction.error
            .flatMap { response -> Driver<Void> in
                return Driver.just(())
            }

        let openCreateFanPassViewController = input.createBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                return Driver.just(self?.uri ?? "")
            }

        let deleteAction = input.deleteFanPass
            .flatMap { (uri, fanPassId) -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.deleteFanPass(uri: uri, fanPassId: fanPassId))
                return Action.makeDriver(response)
            }

        let deleteSuccess = deleteAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                self?.updater.refreshContent.onNext(())
                return Driver.just(LocalizedStrings.msg_delete_fanpass_success.localized())
            }

        let deleteError = deleteAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

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
