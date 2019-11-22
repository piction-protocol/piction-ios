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
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                let title = self.transaction.inOut == "IN" ? LocalizedStrings.menu_deposit_detail.localized() : LocalizedStrings.menu_withdraw_detail.localized()
                return Driver.just(title)
            }

        let transactionDetailAction = Driver.merge(viewWillAppear, loadRetry)
            .filter { self.transaction.transactionType != "VALUE_TRANSFER" }
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                if self.transaction.transactionType == "SPONSORSHIP" {
                    let response =  PictionSDK.rx.requestAPI(MyAPI.sponsorshipTransaction(txHash: self.transaction.transactionHash ?? ""))
                    return Action.makeDriver(response)
                } else if self.transaction.transactionType == "SUBSCRIPTION" {
                    let response = PictionSDK.rx.requestAPI(MyAPI.subscriptionTransaction(txHash: self.transaction.transactionHash ?? ""))
                    return Action.makeDriver(response)
                } else {
                    return Driver.empty()
                }
            }

        let valueTypeInfo = input.viewWillAppear
            .filter { self.transaction.transactionType == "VALUE_TRANSFER" }
            .flatMap { _ -> Driver<[TransactionDetailSection]> in
                return Driver.just([])
            }

        let otherTypeInfo = transactionDetailAction.elements
            .flatMap { [weak self] response -> Driver<[TransactionDetailSection]> in
                guard let `self` = self else { return Driver.empty() }
                let inOut = self.transaction.inOut ?? ""

                if self.transaction.transactionType == "SPONSORSHIP" {
                    guard let sponsorshipItem = try? response.map(to: SponsorshipModel.self) else {
                        return Driver.empty()
                    }
                    let sponsorshipSection = [
                        TransactionDetailSection.header(title: LocalizedStrings.str_sponsorship_info.localized()),
                        TransactionDetailSection.list(title: inOut == "IN" ? LocalizedStrings.str_sponsoredship_to.localized() : LocalizedStrings.str_sponsorship_user.localized(), description: inOut == "IN" ? "@\(sponsorshipItem.sponsor?.loginId ?? "")" : "@\(sponsorshipItem.creator?.loginId ?? "")", link: ""),
                        TransactionDetailSection.footer,
                    ]
                    return Driver.just(sponsorshipSection)
                } else if self.transaction.transactionType == "SUBSCRIPTION" {
                    guard let subscriptionItem = try? response.map(to: SubscriptionModel.self) else {
                        return Driver.empty()
                    }
                    let subscriptionSection = [
                        TransactionDetailSection.info(transaction: self.transaction),
                        TransactionDetailSection.footer,
                        TransactionDetailSection.header(title: inOut == "IN" ? LocalizedStrings.str_fanpass_sales_info.localized() : LocalizedStrings.str_fanpass_purchase_info.localized()),
                        TransactionDetailSection.list(title: LocalizedStrings.str_order_id.localized(), description: "\(subscriptionItem.orderNo ?? 0)", link: ""),
                        TransactionDetailSection.list(title: LocalizedStrings.str_project.localized(), description: "\(subscriptionItem.fanPass?.project?.title ?? "")", link: ""),
                        TransactionDetailSection.list(title: "FAN PASS", description: "\(subscriptionItem.fanPass?.name ?? "")", link: ""),
                        TransactionDetailSection.list(title: inOut == "IN" ? LocalizedStrings.str_buyer.localized() : LocalizedStrings.str_seller.localized(), description: inOut == "IN" ? "\(subscriptionItem.subscriber?.loginId ?? "")" : "\(subscriptionItem.creator?.loginId ?? "")", link: ""),
                        TransactionDetailSection.footer,
                    ]
                    return Driver.just(subscriptionSection)
                }
                return Driver.empty()
            }

        let transactionInfo = Driver.merge(valueTypeInfo, otherTypeInfo)
            .flatMap { [weak self] typeSection -> Driver<SectionType<TransactionDetailSection>> in
                guard let `self` = self else { return Driver.empty() }

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

                return Driver.just(SectionType<TransactionDetailSection>.Section(title: "transactionInfo", items: sections))
            }

        let transactionInfoError = transactionDetailAction.error
            .flatMap { _ in Driver.just(()) }

        let showErrorPopup = transactionInfoError

        let activityIndicator = transactionDetailAction.isExecuting

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
