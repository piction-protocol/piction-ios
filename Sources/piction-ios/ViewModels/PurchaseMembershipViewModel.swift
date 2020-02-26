//
//  PurchaseMembershipViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class PurchaseMembershipViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        KeychainManagerProtocol,
        String,
        MembershipModel
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let keychainManager: KeychainManagerProtocol
    private let uri: String
    private let selectedMembership: MembershipModel

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, keychainManager, uri, selectedMembership) = dependency
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
        let membershipInfo: Driver<(MembershipModel, FeesModel)>
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
        let (firebaseManager, updater, keychainManager, uri, selectedMembership) = (self.firebaseManager, self.updater, self.keychainManager, self.uri, self.selectedMembership)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("Membership구매_\(uri)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, loadRetry)

        let membershipItem = loadPage
            .map { selectedMembership }
            .flatMap(Driver.from)

        let walletInfoAction = loadPage
            .map { WalletAPI.get }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        let walletInfoError = walletInfoAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let projectInfoAction = loadPage
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        let openCheckPincodeViewController = input.purchaseBtnDidTap
            .filter { !keychainManager.get(key: .pincode).isEmpty }
            .map { _ in Void() }

        let purchaseWithoutPicode = input.purchaseBtnDidTap
            .filter { keychainManager.get(key: .pincode).isEmpty }

        let purchaseWithPincode = input.authSuccessWithPincode

        let purchaseAction = Driver.merge(purchaseWithoutPicode, purchaseWithPincode)
            .map { MembershipAPI.sponsorship(uri: uri, membershipId: selectedMembership.id ?? 0, sponsorshipPrice: selectedMembership.price ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let purchaseSuccess = purchaseAction.elements
            .map { _ in "구독 완료" }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let purchaseError = purchaseAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let feesInfoAction = loadPage
            .map { ProjectAPI.fees(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let feesInfoSuccess = feesInfoAction.elements
            .map { try? $0.map(to: FeesModel.self) }
            .flatMap(Driver.from)

        let membershipInfo = Driver.combineLatest(membershipItem, feesInfoSuccess)

        let activityIndicator = Driver.merge(
            walletInfoAction.isExecuting,
            purchaseAction.isExecuting)

        let showErrorPopup = Driver.merge(walletInfoError, purchaseError)
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let dismissViewController = purchaseSuccess

        return Output(
            viewWillAppear: viewWillAppear,
            membershipInfo: membershipInfo,
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

extension ErrorType: Equatable {
    public static func == (lhs: ErrorType, rhs: ErrorType) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized(_), .unauthorized(_)):
            return true
        default:
            return false
        }
    }
}
