//
//  TransactionDetailViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// MARK: - TransactionDetailSection
enum TransactionDetailSection {
    case info(transaction: TransactionModel)
    case header(title: String)
    case list(title: String, description: String, link: String)
    case footer
}

// MARK: - TransactionType
enum TransactionType {
    case sponsorship
    case subscription
}

// MARK: - ViewModel
final class TransactionDetailViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        TransactionModel
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let transaction: TransactionModel

    init(dependency: Dependency) {
        (firebaseManager, transaction) = dependency
    }

    var loadRetryTrigger = PublishSubject<Void>()
}

// MARK: - Input & Output
extension TransactionDetailViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let navigationTitle: Driver<String>
        let selectedIndexPath: Driver<IndexPath>
        let transactionInfo: Driver<SectionType<TransactionDetailSection>>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension TransactionDetailViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, transaction) = (self.firebaseManager, self.transaction)

        // 화면이 보여지기 전에
        let navigationTitle = input.viewWillAppear
            .map { transaction.inOut == "IN" ? LocalizationKey.menu_deposit_detail.localized() : LocalizationKey.menu_withdraw_detail.localized() }
            .do(onNext: { title in
                // analytics screen event
                firebaseManager.screenName("마이페이지_거래내역_\(title)")
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
        // 전달받은 transaction type이 sponsorship이면
        // sponsorship transaction 정보 호출
        let sponsorshipTransactionAction = Driver.merge(initialLoad, loadRetry)
            .filter { transaction.transactionType == "SPONSORSHIP" }
            .map { WalletAPI.sponsorshipTransaction(txHash: transaction.transactionHash ?? "") }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // sponsorship trasnaction 정보 호출 성공 시
        let sponsorshipTransactionSuccess = sponsorshipTransactionAction.elements
            .map { try? $0.map(to: TransactionSponsorshipModel.self) }
            .map { [
                TransactionDetailSection.header(title: transaction.inOut ?? "" == "IN" ? LocalizationKey.str_membership_sell_info.localized() : LocalizationKey.str_membership_buy_info.localized()),
                TransactionDetailSection.list(title: LocalizationKey.str_order_id.localized(), description: "\($0?.orderNo ?? 0)", link: ""),
                TransactionDetailSection.list(title: LocalizationKey.str_project.localized(), description: "\($0?.projectName ?? "")", link: ""),
                TransactionDetailSection.list(title: LocalizationKey.str_membership.localized(), description: "\($0?.membershipName ?? "")", link: ""),
                TransactionDetailSection.list(title: transaction.inOut ?? "" == "IN" ? LocalizationKey.str_membership_buyer.localized() : LocalizationKey.str_membership_seller.localized(), description: transaction.inOut ?? "" == "IN" ? "\($0?.sponsor?.loginId ?? "")" : "\($0?.creator?.loginId ?? "")", link: ""),
                TransactionDetailSection.footer,
            ] }

        // sponsorship trasnaction 정보 호출 에러 시
        let transactionInfoError = sponsorshipTransactionAction.error
            .map { _ in Void() }

        // sponsorship transaction 정보
        let sponsorshipTypeInfo = sponsorshipTransactionSuccess

        // 최초 진입 시
        // transaction type이 VALUE_TRANSFER이면
        let valueTypeInfo = initialLoad
            .filter { transaction.transactionType == "VALUE_TRANSFER" }
            .map { [TransactionDetailSection]() }

        // transaction 정보 조합
        let transactionInfo = Driver.merge(valueTypeInfo, sponsorshipTypeInfo)
            .map { typeSection -> [TransactionDetailSection] in
                var sections: [TransactionDetailSection] = [
                    TransactionDetailSection.info(transaction: transaction),
                    TransactionDetailSection.footer
                ]
                sections.append(contentsOf: typeSection)

                let transactionSection = [
                    TransactionDetailSection.header(title: LocalizationKey.str_transaction_info.localized()),
                    TransactionDetailSection.list(title: "From", description: transaction.fromAddress ?? "", link: ""),
                    TransactionDetailSection.list(title: "To", description: transaction.toAddress ?? "", link: ""),
                    TransactionDetailSection.list(title: "Amount", description: "\((transaction.amount ?? 0).commaRepresentation) PXL", link: ""),
                    TransactionDetailSection.list(title: "Block #", description: String(transaction.blockNumber ?? 0) , link: ""),
                    TransactionDetailSection.list(title: "TX HASH", description: transaction.transactionHash ?? "", link: transaction.txHashWithUrl ?? ""),
                    TransactionDetailSection.footer
                ]
                sections.append(contentsOf: transactionSection)
                return sections
            }
            .map { SectionType<TransactionDetailSection>.Section(title: "transactionInfo", items: $0) }

        // 에러 팝업 출력
        let showErrorPopup = transactionInfoError

        // 로딩 뷰
        let activityIndicator = sponsorshipTransactionAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            navigationTitle: navigationTitle,
            selectedIndexPath: input.selectedIndexPath,
            transactionInfo: transactionInfo,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
