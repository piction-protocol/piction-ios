//
//  TransactionHistoryViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

enum TransactionHistorySection {
    case header
    case year(model: String)
    case list(model: TransactionModel, dateTitle: Bool)
    case footer
}

final class TransactionHistoryViewModel: ViewModel {

    var page = 0
    var sections: [TransactionModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let transactionList: Driver<SectionType<TransactionHistorySection>>
        let isFetching: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let openTransactionDetailViewController: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let initialPage = Driver.merge(initialLoad, input.refreshControlDidRefresh)
            .do(onNext: { [weak self] in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let transactionHistoryAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { WalletAPI.transactions(page: self.page + 1, size: 30) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

       let transactionHistorySuccess = transactionHistoryAction.elements
            .map { try? $0.map(to: PageViewResponse<TransactionModel>.self) }
            .do(onNext: { [weak self] pageList in
                guard
                    let page = self?.page,
                    let pageNumber = pageList?.pageable?.pageNumber,
                    let totalPages = pageList?.totalPages
                else { return }

                self?.shouldInfiniteScroll = pageNumber < totalPages - 1
                self?.page = page + 1
            })
            .map { self.sections.append(contentsOf: $0?.content ?? []) }
            .map { [weak self] _ -> [TransactionHistorySection] in
                guard let `self` = self else { return [] }
                var transactions: [TransactionHistorySection] = []

                let yearGroup = self.groupedBy(self.sections, dateComponents: [.year])

                for (index, element) in yearGroup.sorted(by: { $0.0 > $1.0 }).enumerated() {
                    if index != 0 {
                        transactions.append(contentsOf: [.year(model: element.key.toString(format: "YYYY"))])
                    }
                    let dayGroup = self.groupedBy(element.value, dateComponents: [.year, .month, .day])
                    for item in dayGroup.sorted(by: { $0.0 > $1.0 }) {
                        transactions.append(contentsOf: [.header])
                        let transaction: [TransactionHistorySection] = (item.value).enumerated().map { .list(model: $1, dateTitle: $0 == 0) }
                        transactions.append(contentsOf: transaction)
                        transactions.append(contentsOf: [.footer])
                    }
                }
                return transactions
            }
            .map { SectionType<TransactionHistorySection>.Section(title: "transacation", items: $0) }

        let transactionHistoryEmptyList = transactionHistoryAction.error
            .map { _ in SectionType<TransactionHistorySection>.Section(title: "transacation", items: []) }

        let transactionHistoryListError = transactionHistoryAction.error
            .flatMap { response -> Driver<Void> in
                let errorMsg = response as? ErrorType
                switch errorMsg {
                case .unauthorized:
                    return Driver.empty()
                default:
                    return Driver.just(())
                }
            }

        let transactionHistoryList = Driver.merge(transactionHistorySuccess, transactionHistoryEmptyList)
        let showErrorPopup = transactionHistoryListError

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(transactionHistorySuccess)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let showActivityIndicator = initialPage
            .map { true }

        let hideActivityIndicator = transactionHistoryList
            .map { _ in false }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        let embedEmptyViewController = transactionHistorySuccess
            .filter { $0.items.isEmpty }
            .map { _ in .transactionListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        return Output(
            viewWillAppear: input.viewWillAppear,
            transactionList: transactionHistorySuccess,
            isFetching: refreshAction.isExecuting,
            embedEmptyViewController: embedEmptyViewController,
            openTransactionDetailViewController: input.selectedIndexPath,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }

    func groupedBy(_ list: [TransactionModel], dateComponents: Set<Calendar.Component>) -> [Date: [TransactionModel]] {
        let empty: [Date: [TransactionModel]] = [:]
        return list.reduce(into: empty) { acc, cur in
            let components = Calendar.current.dateComponents(dateComponents, from: cur.createdAt ?? Date())
            let date = Calendar.current.date(from: components)!
            let existing = acc[date] ?? []
            acc[date] = existing + [cur]
        }
    }
}
