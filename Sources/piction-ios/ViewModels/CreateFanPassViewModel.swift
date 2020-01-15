//
//  CreateFanPassViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CreateFanPassViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String,
        FanPassModel?
    )

    let updater: UpdaterProtocol
    let uri: String
    let fanPass: FanPassModel?

    private let name = PublishSubject<String>()
    private let price = PublishSubject<String?>()
    private let description = PublishSubject<String?>()
    private let limit = PublishSubject<String?>()

    init(dependency: Dependency) {
        (updater, uri, fanPass) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let fanPassName: Driver<String>
        let fanPassPrice: Driver<String?>
        let fanPassDescription: Driver<String?>
        let fanPassLimit: Driver<String?>
        let limitBtnDidTap: Driver<Void>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let loadFanPass: Driver<FanPassModel>
        let limitBtnDidTap: Driver<Void>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Void>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri, fanPass) = (self.updater, self.uri, self.fanPass)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadFanPass = viewWillAppear
            .map { fanPass }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] fanPass in
                self?.name.onNext(fanPass.name ?? "")
                self?.price.onNext(String(fanPass.subscriptionPrice ?? 0))
                self?.description.onNext(fanPass.description ?? "")
                if fanPass.subscriptionLimit == nil {
                    self?.limit.onNext(nil)
                } else {
                    self?.limit.onNext(String(fanPass.subscriptionLimit ?? 0))
                }
            })

        let nameChanged = Driver.merge(input.fanPassName, name.asDriver(onErrorDriveWith: .empty()))

        let priceChanged = Driver.merge(input.fanPassPrice,
            price.asDriver(onErrorDriveWith: .empty()))

        let descriptionChanged = Driver.merge(input.fanPassDescription,
            description.asDriver(onErrorDriveWith: .empty()))

        let noLimit = input.limitBtnDidTap
            .map { String?(nil) }
            .do(onNext: { [weak self] _ in
                self?.limit.onNext(nil)
            })

        let inputLimit = input.fanPassLimit
            .do(onNext: { [weak self] limit in
                self?.limit.onNext(limit)
            })

        let limitChanged = Driver.merge(inputLimit, noLimit)
            .do(onNext: { [weak self] limit in
                self?.limit.onNext(limit)
            })

        let fanPassInfo = Driver.combineLatest(
            nameChanged,
            priceChanged,
            descriptionChanged,
            limitChanged) { (name: $0, price: $1, description: $2, limit: $3) }

        let createFanPassAction = input.saveBtnDidTap
            .filter { fanPass == nil }
            .withLatestFrom(fanPassInfo)
            .map { FanPassAPI.create(uri: uri, name: $0.name, description: $0.description, thumbnail: nil, subscriptionLimit: Int($0.limit ?? "") ?? nil, subscriptionPrice: Int($0.price ?? "") ?? nil) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let updateFanPassAction = input.saveBtnDidTap
            .filter { fanPass != nil }
            .withLatestFrom(fanPassInfo)
            .map { FanPassAPI.update(uri: uri, fanPassId: fanPass?.id ?? 0, name: $0.name, description: $0.description, thumbnail: nil, subscriptionLimit: Int($0.limit ?? "") ?? nil, subscriptionPrice: Int($0.price ?? "") ?? nil) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let saveFanPassAction = Driver.merge(createFanPassAction, updateFanPassAction)

        let dismissKeyboard = Driver.merge(input.saveBtnDidTap, input.limitBtnDidTap)

        let popViewController = saveFanPassAction.elements
            .map { _ in Void() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let showToast = saveFanPassAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let activityIndicator = saveFanPassAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            loadFanPass: loadFanPass,
            limitBtnDidTap: input.limitBtnDidTap,
            popViewController: popViewController,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            showToast: showToast
        )
    }
}
