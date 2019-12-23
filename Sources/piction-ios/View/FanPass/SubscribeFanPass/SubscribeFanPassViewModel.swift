//
//  SubscribeFanPassViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SubscribeFanPassViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        String,
        FanPassModel
    )

    let updater: UpdaterProtocol
    let uri: String
    let selectedFanPass: FanPassModel

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, uri, selectedFanPass) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let descriptionBtnDidTap: Driver<Void>
        let agreeBtnDidTap: Driver<Void>
        let purchaseBtnDidTap: Driver<Void>
        let authSuccessWithPincode: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let fanPassInfo: Driver<(FanPassModel, FeesModel)>
        let walletInfo: Driver<WalletModel>
        let projectInfo: Driver<ProjectModel>
        let descriptionBtnDidTap: Driver<Void>
        let agreeBtnDidTap: Driver<Void>
        let openCheckPincodeViewController: Driver<Void>
        let showErrorPopup: Driver<String>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri, selectedFanPass) = (self.updater, self.uri, self.selectedFanPass)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, loadRetry)

        let fanPassItem = initialLoad
            .flatMap {  _ in Driver<FanPassModel>.just(selectedFanPass) }

        let walletInfoAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.wallet)
                return Action.makeDriver(response)
            }

        let walletInfoSuccess = walletInfoAction.elements
            .flatMap { response -> Driver<WalletModel> in
                guard let wallet = try? response.map(to: WalletModel.self) else { return Driver.empty() }
                return Driver.just(wallet)
            }

        let walletInfoError = walletInfoAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let projectInfoAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: uri))
                return Action.makeDriver(response)
            }

        let projectInfoSuccess = projectInfoAction.elements
            .flatMap { response -> Driver<ProjectModel> in
                guard let projectInfo = try? response.map(to: ProjectModel.self) else { return Driver.empty() }
                return Driver.just(projectInfo)
            }

        let purchaseAction = input.purchaseBtnDidTap
            .filter { KeychainManager.get(key: "pincode").isEmpty }
            .flatMap { _ -> Driver<Action<ResponseData>> in
                guard
                    let fanPassId = selectedFanPass.id,
                    let subscriptionPrice = selectedFanPass.subscriptionPrice
                else { return Driver.empty() }

                let response = PictionSDK.rx.requestAPI(ProjectsAPI.subscription(uri: uri, fanPassId: fanPassId, subscriptionPrice: subscriptionPrice))
                return Action.makeDriver(response)
            }

        let openCheckPincodeViewController = input.purchaseBtnDidTap
            .filter { !KeychainManager.get(key: "pincode").isEmpty }
            .flatMap { _ in Driver.just(()) }

        let purchaseWithPincodeAction = input.authSuccessWithPincode
            .flatMap { _ -> Driver<Action<ResponseData>> in
                guard
                    let fanPassId = selectedFanPass.id,
                    let subscriptionPrice = selectedFanPass.subscriptionPrice
                else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.subscription(uri: uri, fanPassId: fanPassId, subscriptionPrice: subscriptionPrice))
                return Action.makeDriver(response)
            }

        let purchaseSuccess = Driver.merge(purchaseAction.elements, purchaseWithPincodeAction.elements)
            .flatMap { _ -> Driver<String> in
                updater.refreshContent.onNext(())
                return Driver.just("구독 완료")
            }

        let purchaseError = purchaseAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let feesInfoAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.fees(uri: uri))
                return Action.makeDriver(response)
            }

        let feesInfoSuccess = feesInfoAction.elements
            .flatMap { response -> Driver<FeesModel> in
                guard let fees = try? response.map(to: FeesModel.self) else { return Driver.empty() }
                return Driver.just(fees)
            }

        let fanPassInfo = Driver.combineLatest(fanPassItem, feesInfoSuccess)

        let activityIndicator = Driver.merge(
            walletInfoAction.isExecuting,
            purchaseAction.isExecuting,
            purchaseWithPincodeAction.isExecuting)

        let showErrorPopup = Driver.merge(walletInfoError, purchaseError)
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let dismissViewController = purchaseSuccess

        return Output(
            viewWillAppear: input.viewWillAppear,
            fanPassInfo: fanPassInfo,
            walletInfo: walletInfoSuccess,
            projectInfo: projectInfoSuccess,
            descriptionBtnDidTap: input.descriptionBtnDidTap,
            agreeBtnDidTap: input.agreeBtnDidTap,
            openCheckPincodeViewController: openCheckPincodeViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController
        )
    }
}
