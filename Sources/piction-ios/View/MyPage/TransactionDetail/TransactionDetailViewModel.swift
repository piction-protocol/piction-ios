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

enum TransactionType {
    case sponsorship
    case subscription
}

final class TransactionDetailViewModel: ViewModel {

    let transaction: TransactionModel

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
        let transactionInfo: Driver<TransactionDetailBySection>
    }


    func build(input: Input) -> Output {
        let navigationTitle = input.viewWillAppear
            .flatMap { [weak self] _ -> Driver<String> in
                guard let `self` = self else { return Driver.empty() }
                let title = self.transaction.inOut == "IN" ? "입금 상세정보" : "출금 상세정보"
                return Driver.just(title)
            }

        let transactionDetailAction = input.viewWillAppear
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
            .flatMap { _ -> Driver<[TransactionDetailItemType]> in
                return Driver.just([])
            }

        let otherTypeInfo = transactionDetailAction.elements
            .flatMap { [weak self] response -> Driver<[TransactionDetailItemType]> in
                guard let `self` = self else { return Driver.empty() }
                let inOut = self.transaction.inOut ?? ""

                if self.transaction.transactionType == "SPONSORSHIP" {
                    guard let sponsorshipItem = try? response.map(to: SponsorshipModel.self) else {
                        return Driver.empty()
                    }
                    let sponsorshipSection = [
                        TransactionDetailItemType.header(title: "후원 정보"),
                        TransactionDetailItemType.list(title: inOut == "IN" ? "후원자" : "후원 대상", description: inOut == "IN" ? "@\(sponsorshipItem.sponsor?.loginId ?? "")" : "@\(sponsorshipItem.creator?.loginId ?? "")", link: ""),
                        TransactionDetailItemType.footer,
                    ]
                    return Driver.just(sponsorshipSection)
                } else if self.transaction.transactionType == "SUBSCRIPTION" {
                    guard let subscriptionItem = try? response.map(to: SubscriptionModel.self) else {
                        return Driver.empty()
                    }
                    let subscriptionSection = [
                        TransactionDetailItemType.info(transaction: self.transaction),
                        TransactionDetailItemType.footer,
                        TransactionDetailItemType.header(title: inOut == "IN" ? "FAN PASS 판매 정보" : "FAN PASS 구매 정보"),
                        TransactionDetailItemType.list(title: "주문번호", description: "\(subscriptionItem.orderNo ?? 0)", link: ""),
                        TransactionDetailItemType.list(title: "프로젝트", description: "\(subscriptionItem.fanPass?.project?.title ?? "")", link: ""),
                        TransactionDetailItemType.list(title: "FAN PASS", description: "\(subscriptionItem.fanPass?.name ?? "")", link: ""),
                        TransactionDetailItemType.list(title: inOut == "IN" ? "구매자" : "판매자", description: inOut == "IN" ? "\(subscriptionItem.subscriber?.loginId ?? "")" : "\(subscriptionItem.creator?.loginId ?? "")", link: ""),
                        TransactionDetailItemType.footer,
                    ]
                    return Driver.just(subscriptionSection)
                }
                return Driver.empty()
            }

        let transactionInfo = Driver.merge(valueTypeInfo, otherTypeInfo)
            .flatMap { [weak self] typeSection -> Driver<TransactionDetailBySection> in
                guard let `self` = self else { return Driver.empty() }

                var sections: [TransactionDetailItemType] = [
                    TransactionDetailItemType.info(transaction: self.transaction),
                    TransactionDetailItemType.footer
                ]

                sections.append(contentsOf: typeSection)

                let transactionSection = [
                    TransactionDetailItemType.header(title: "트랜잭션 정보"),
                    TransactionDetailItemType.list(title: "From", description: self.transaction.fromAddress ?? "", link: ""),
                    TransactionDetailItemType.list(title: "To", description: self.transaction.toAddress ?? "", link: ""),
                    TransactionDetailItemType.list(title: "Amount", description: "\((self.transaction.amount ?? 0).commaRepresentation) PXL", link: ""),
                    TransactionDetailItemType.list(title: "Block #", description: String(self.transaction.blockNumber ?? 0) , link: ""),
                    TransactionDetailItemType.list(title: "TX HASH", description: self.transaction.transactionHash ?? "", link: self.transaction.txHashWithUrl ?? ""),
                    TransactionDetailItemType.footer
                ]

                sections.append(contentsOf: transactionSection)

                return Driver.just(TransactionDetailBySection.Section(title: "transactionInfo", items: sections))
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            navigationTitle: navigationTitle,
            selectedIndexPath: input.selectedIndexPath,
            transactionInfo: transactionInfo
        )
    }
}
