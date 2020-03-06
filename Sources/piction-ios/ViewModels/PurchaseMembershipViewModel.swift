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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension PurchaseMembershipViewModel {
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
}

// MARK: - ViewModel Build
extension PurchaseMembershipViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keychainManager, uri, selectedMembership) = (self.firebaseManager, self.updater, self.keychainManager, self.uri, self.selectedMembership)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("Membership구매_\(uri)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 새로고침 필요 시
        let loadPage = Driver.merge(initialLoad, loadRetry)

        // 최초 진입 시, 새로고침 필요 시
        // 선택된 멤버십 정보
        let membershipItem = loadPage
            .map { selectedMembership }
            .flatMap(Driver.from)

        // 최초 진입 시, 새로고침 필요 시
        // 지갑 정보 호출
        let walletInfoAction = loadPage
            .map { WalletAPI.get }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 지갑 정보 호출 성공 시
        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        // 지갑 정보 호출 에러 시
        let walletInfoError = walletInfoAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 최초 진입 시, 새로고침 필요 시
        // 프로젝트 정보 호출
        let projectInfoAction = loadPage
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 정보 호출 성공 시
        let projectInfoSuccess = projectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        // 결제 버튼 눌렀을 때 pincode가 설정되어 있으면 check pincode 화면 출력
        let openCheckPincodeViewController = input.purchaseBtnDidTap
            .filter { !keychainManager.get(key: .pincode).isEmpty }
            .map { _ in Void() }

        // 결제 버튼 눌렀을때 pincode가 설정되어 있지 않은 상태
        let purchaseWithoutPicode = input.purchaseBtnDidTap
            .filter { keychainManager.get(key: .pincode).isEmpty }

        // pincode 인증 성공 시
        let purchaseWithPincode = input.authSuccessWithPincode

        // pincode가 설정되어 있지 않거나 pincode 인증 성공 시
        // 후원 결제 호출
        let purchaseAction = Driver.merge(purchaseWithoutPicode, purchaseWithPincode)
            .map { MembershipAPI.sponsorship(uri: uri, membershipId: selectedMembership.id ?? 0, sponsorshipPrice: selectedMembership.price ?? 0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 후원 결제 호출 성공 시
        let purchaseSuccess = purchaseAction.elements
            .map { _ in "구독 완료" }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 후원 결제 호출 에러 시
        let purchaseError = purchaseAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 최초 진입 시, 새로고침 필요 시
        // 수수료 정보 호출
        let feesInfoAction = loadPage
            .map { ProjectAPI.fees(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 수수료 정보 호출 성공 시
        let feesInfoSuccess = feesInfoAction.elements
            .map { try? $0.map(to: FeesModel.self) }
            .flatMap(Driver.from)

        // 멤버십 정보와 수수료 정보 호출 조합
        // 멤버십 정보
        let membershipInfo = Driver.combineLatest(membershipItem, feesInfoSuccess)

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            walletInfoAction.isExecuting,
            purchaseAction.isExecuting)

        // 에러 팝업 출력
        let showErrorPopup = Driver.merge(walletInfoError, purchaseError)
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 결제 성공 시 dismiss
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
