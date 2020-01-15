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

final class TransactionDetailViewModel: ViewModel {

    let transaction: TransactionModel
    var loadRetryTrigger = PublishSubject<Void>()

    init(transaction: TransactionModel) {
        self.transaction = transaction
    }

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
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let navigationTitle = Driver.merge(viewWillAppear, loadRetry)
            .map { self.transaction.inOut == "IN" ? LocalizedStrings.menu_deposit_detail.localized() : LocalizedStrings.menu_withdraw_detail.localized() }

        let transactionSponsorshipAction = Driver.merge(viewWillAppear, loadRetry)
            .filter { self.transaction.transactionType != "VALUE_TRANSFER" }
            .filter { self.transaction.transactionType == "SPONSORSHIP" }
            .map { WalletAPI.sponsorshipTransaction(txHash: self.transaction.transactionHash ?? "") }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let transactionSubscriptionAction = Driver.merge(viewWillAppear, loadRetry)
            .filter { self.transaction.transactionType != "VALUE_TRANSFER" }
            .filter { self.transaction.transactionType == "SUBSCRIPTION" }
            .map { WalletAPI.subscriptionTransaction(txHash: self.transaction.transactionHash ?? "") }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let valueTypeInfo = input.viewWillAppear
            .filter { self.transaction.transactionType == "VALUE_TRANSFER" }
            .map { [TransactionDetailSection]() }

        let transactionSponsorshipSuccess = transactionSponsorshipAction.elements
            .map { try? $0.map(to: TransactionSponsorshipModel.self) }
            .map { [
                TransactionDetailSection.header(title: LocalizedStrings.str_sponsorship_info.localized()),
                TransactionDetailSection.list(title: self.transaction.inOut ?? "" == "IN" ? LocalizedStrings.str_sponsoredship_to.localized() : LocalizedStrings.str_sponsorship_user.localized(), description: self.transaction.inOut ?? "" == "IN" ? "@\($0?.sponsor?.loginId ?? "")" : "@\($0?.creator?.loginId ?? "")", link: ""),
                TransactionDetailSection.footer,
            ] }

        let transactionSubscriptionSuccess = transactionSubscriptionAction.elements
            .map { try? $0.map(to: TransactionSubscriptionModel.self) }
            .map { [
                TransactionDetailSection.header(title: self.transaction.inOut ?? "" == "IN" ? LocalizedStrings.str_fan_pass_sell_info.localized() : LocalizedStrings.str_fan_pass_buy_info.localized()),
                TransactionDetailSection.list(title: LocalizedStrings.str_order_id.localized(), description: "\($0?.orderNo ?? 0)", link: ""),
                TransactionDetailSection.list(title: LocalizedStrings.str_project.localized(), description: "\($0?.projectName ?? "")", link: ""),
                TransactionDetailSection.list(title: "FAN PASS", description: "\($0?.fanPassName ?? "")", link: ""),
                TransactionDetailSection.list(title: self.transaction.inOut ?? "" == "IN" ? LocalizedStrings.str_buyer.localized() : LocalizedStrings.str_seller.localized(), description: self.transaction.inOut ?? "" == "IN" ? "\($0?.subscriber?.loginId ?? "")" : "\($0?.creator?.loginId ?? "")", link: ""),
                TransactionDetailSection.footer,
            ] }

        let otherTypeInfo = Driver.merge(transactionSponsorshipSuccess, transactionSubscriptionSuccess)

        let transactionInfo = Driver.merge(valueTypeInfo, otherTypeInfo)
            .map { [weak self] typeSection -> [TransactionDetailSection] in
                guard let `self` = self else { return [] }

                var sections: [TransactionDetailSection] = [
                    TransactionDetailSection.info(transaction: self.transaction),
                    TransactionDetailSection.footer
                ]
                sections.append(contentsOf: typeSection)

                let transactionSection = [
                    TransactionDetailSection.header(title: LocalizedStrings.str_transaction_info.localized()),
                    TransactionDetailSection.list(title: "From", description: self.transaction.fromAddress ?? "", link: ""),
                    TransactionDetailSection.list(title: "To", description: self.transaction.toAddress ?? "", link: ""),
                    TransactionDetailSection.list(title: "Amount", description: "\((self.transaction.amount ?? 0).commaRepresentation) PXL", link: ""),
                    TransactionDetailSection.list(title: "Block #", description: String(self.transaction.blockNumber ?? 0) , link: ""),
                    TransactionDetailSection.list(title: "TX HASH", description: self.transaction.transactionHash ?? "", link: self.transaction.txHashWithUrl ?? ""),
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
