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

enum TransactionDetailSection {
    case info(transaction: TransactionModel)
    case header(title: String)
    case list(title: String, description: String, link: String)
    case footer
}

enum TransactionType {
    case sponsorship
    case subscription
}

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

    func build(input: Input) -> Output {
        let (firebaseManager, transaction) = (self.firebaseManager, self.transaction)

        let navigationTitle = input.viewWillAppear
            .map { transaction.inOut == "IN" ? LocalizedStrings.menu_deposit_detail.localized() : LocalizedStrings.menu_withdraw_detail.localized() }
            .do(onNext: { title in
                firebaseManager.screenName("마이페이지_거래내역_\(title)")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let transactionSponsorshipAction = Driver.merge(initialLoad, loadRetry)
            .filter { transaction.transactionType != "VALUE_TRANSFER" }
            .filter { transaction.transactionType == "SPONSORSHIP" }
            .map { WalletAPI.sponsorshipTransaction(txHash: transaction.transactionHash ?? "") }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let transactionSubscriptionAction = Driver.merge(initialLoad, loadRetry)
            .filter { transaction.transactionType != "VALUE_TRANSFER" }
            .filter { transaction.transactionType == "SUBSCRIPTION" }
            .map { WalletAPI.subscriptionTransaction(txHash: transaction.transactionHash ?? "") }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let valueTypeInfo = input.viewWillAppear
            .filter { transaction.transactionType == "VALUE_TRANSFER" }
            .map { [TransactionDetailSection]() }

        let transactionSponsorshipSuccess = transactionSponsorshipAction.elements
            .map { try? $0.map(to: TransactionSponsorshipModel.self) }
            .map { [
                TransactionDetailSection.header(title: LocalizedStrings.str_sponsorship_info.localized()),
                TransactionDetailSection.list(title: transaction.inOut ?? "" == "IN" ? LocalizedStrings.str_sponsoredship_to.localized() : LocalizedStrings.str_sponsorship_user.localized(), description: transaction.inOut ?? "" == "IN" ? "@\($0?.sponsor?.loginId ?? "")" : "@\($0?.creator?.loginId ?? "")", link: ""),
                TransactionDetailSection.footer,
            ] }

        let transactionSubscriptionSuccess = transactionSubscriptionAction.elements
            .map { try? $0.map(to: TransactionSubscriptionModel.self) }
            .map { [
                TransactionDetailSection.header(title: transaction.inOut ?? "" == "IN" ? LocalizedStrings.str_fan_pass_sell_info.localized() : LocalizedStrings.str_fan_pass_buy_info.localized()),
                TransactionDetailSection.list(title: LocalizedStrings.str_order_id.localized(), description: "\($0?.orderNo ?? 0)", link: ""),
                TransactionDetailSection.list(title: LocalizedStrings.str_project.localized(), description: "\($0?.projectName ?? "")", link: ""),
                TransactionDetailSection.list(title: "FAN PASS", description: "\($0?.fanPassName ?? "")", link: ""),
                TransactionDetailSection.list(title: transaction.inOut ?? "" == "IN" ? LocalizedStrings.str_buyer.localized() : LocalizedStrings.str_seller.localized(), description: transaction.inOut ?? "" == "IN" ? "\($0?.subscriber?.loginId ?? "")" : "\($0?.creator?.loginId ?? "")", link: ""),
                TransactionDetailSection.footer,
            ] }

        let otherTypeInfo = Driver.merge(transactionSponsorshipSuccess, transactionSubscriptionSuccess)

        let transactionInfo = Driver.merge(valueTypeInfo, otherTypeInfo)
            .map { typeSection -> [TransactionDetailSection] in
                var sections: [TransactionDetailSection] = [
                    TransactionDetailSection.info(transaction: transaction),
                    TransactionDetailSection.footer
                ]
                sections.append(contentsOf: typeSection)

                let transactionSection = [
                    TransactionDetailSection.header(title: LocalizedStrings.str_transaction_info.localized()),
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

        let transactionInfoError = Driver.merge(
            transactionSponsorshipAction.error,
            transactionSubscriptionAction.error)
            .map { _ in Void() }

        let showErrorPopup = transactionInfoError

        let activityIndicator = Driver.merge(
            transactionSponsorshipAction.isExecuting,
            transactionSubscriptionAction.isExecuting)

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
