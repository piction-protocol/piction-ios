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

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadFanPass = viewWillAppear
            .flatMap { [weak self] _ -> Driver<FanPassModel> in
                guard let fanPass = self?.fanPass else { return Driver.empty() }

                self?.name.onNext(fanPass.name ?? "")
                self?.price.onNext(String(fanPass.subscriptionPrice ?? 0))
                self?.description.onNext(fanPass.description ?? "")
                if fanPass.subscriptionLimit == nil {
                    self?.limit.onNext(nil)
                } else {
                    self?.limit.onNext(String(fanPass.subscriptionLimit ?? 0))
                }
                return Driver.just(fanPass)
            }

        let nameChanged = Driver.merge(input.fanPassName, name.asDriver(onErrorDriveWith: .empty()))

        let priceChanged = Driver.merge(input.fanPassPrice,
            price.asDriver(onErrorDriveWith: .empty()))

        let descriptionChanged = Driver.merge(input.fanPassDescription,
            description.asDriver(onErrorDriveWith: .empty()))

        let noLimit = input.limitBtnDidTap
            .flatMap { [weak self] _ -> Driver<String?> in
                self?.limit.onNext(nil)
                return Driver<String?>.just(nil)
            }

        let inputLimit = input.fanPassLimit
            .flatMap { [weak self] limit ->  Driver<String?> in
                self?.limit.onNext(limit)
                return Driver<String?>.just(limit)
            }

        let limitChanged = Driver.merge(inputLimit, noLimit)
            .flatMap { [weak self] limit -> Driver<String?> in
                self?.limit.onNext(limit)
                return Driver<String?>.just(limit)
            }

        let fanPassInfo = Driver.combineLatest(
            nameChanged,
            priceChanged,
            descriptionChanged,
            limitChanged) { (name: $0, price: $1, description: $2, limit: $3) }
            .do(onNext: { info in
                print(info)
            })

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(fanPassInfo)
            .flatMap { [weak self] fanPassInfo -> Driver<Action<ResponseData>> in
                if self?.fanPass == nil {
                    let response = PictionSDK.rx.requestAPI(ProjectsAPI.createFanPass(uri: self?.uri ?? "", name: fanPassInfo.name, description: fanPassInfo.description, thumbnail: nil, subscriptionLimit: Int(fanPassInfo.limit ?? "") ?? nil, subscriptionPrice: Int(fanPassInfo.price ?? "") ?? nil))
                    return Action.makeDriver(response)
                } else {
                    let response = PictionSDK.rx.requestAPI(ProjectsAPI.updateFanPass(uri: self?.uri ?? "", fanPassId: self?.fanPass?.id ?? 0, name: fanPassInfo.name, description: fanPassInfo.description, thumbnail: nil, subscriptionLimit: Int(fanPassInfo.limit ?? "") ?? nil, subscriptionPrice: Int(fanPassInfo.price ?? "") ?? nil))
                    return Action.makeDriver(response)
                }
        }

        let dismissKeyboard = Driver.merge(input.saveBtnDidTap, input.limitBtnDidTap)

        let popViewController = saveButtonAction.elements
            .flatMap { [weak self] response -> Driver<Void> in
                guard let _ = try? response.map(to: FanPassModel.self) else {
                    return Driver.empty()
                }
                self?.updater.refreshContent.onNext(())
                return Driver.just(())
            }

        let showToast = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let activityIndicator = saveButtonAction.isExecuting

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
