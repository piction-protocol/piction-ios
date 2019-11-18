//
//  HomeViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK
import RxDataSources

final class HomeViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var loadTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let loadComplete: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let embedHomeSection: Driver<Void>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())

        let embedHomeSection = Driver.merge(viewWillAppear, refreshSession, refreshContent, input.refreshControlDidRefresh, loadNext)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(input.loadComplete)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let showActivityIndicator = embedHomeSection
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = input.loadComplete
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)
            .flatMap { status in Driver.just(status) }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            embedHomeSection: embedHomeSection,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator
        )
    }
}
