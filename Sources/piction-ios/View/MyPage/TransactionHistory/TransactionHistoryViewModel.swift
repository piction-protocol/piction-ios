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
import RxPictionSDK

final class TransactionHistoryViewModel: ViewModel {

    var page = 0
    var sections: [TransactionModel] = []
    var shouldInfiniteScroll = true

    var loadTrigger = PublishSubject<Void>()

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let transactionList: Driver<TransactionHistoryBySection>
        let isFetching: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let activityIndicator: Driver<Bool>
        let openTransactionDetailViewController: Driver<IndexPath>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, input.refreshControlDidRefresh)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.page = 1
                self.sections = []
                self.shouldInfiniteScroll = true
                return Driver.just(())
            }

        let loadNext = loadTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                self.page = self.page + 1
                return Driver.just(())
            }

        let transactionHistoryAction = Driver.merge(initialLoad, loadNext)
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(MyAPI.transactions(page: self.page, size: 30))
                return Action.makeDriver(response)
            }

       let transactionHistorySuccess = transactionHistoryAction.elements
            .flatMap { [weak self] response -> Driver<TransactionHistoryBySection> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<TransactionModel>.self) else {
                    return Driver.empty()
                }
                if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                self.sections.append(contentsOf: pageList.content ?? [])

                var transactions: [TransactionHistoryItemType] = []

                let yearGroup = self.groupedBy(self.sections, dateComponents: [.year, .month])

                for (index, element) in yearGroup.sorted(by: { $0.0 > $1.0 }).enumerated() {
                    if index != 0 {
                        transactions.append(contentsOf: [.year(model: element.key.toString(format: "YYYY"))])
                    }
                    let dayGroup = self.groupedBy(element.value, dateComponents: [.year, .month, .day])
                    for item in dayGroup.sorted(by: { $0.0 > $1.0 }) {
                        transactions.append(contentsOf: [.header])
                        let transaction: [TransactionHistoryItemType] = (item.value).enumerated().map { .list(model: $1, dateTitle: $0 == 0) }
                        transactions.append(contentsOf: transaction)
                        transactions.append(contentsOf: [.footer])
                    }
                }

                return Driver.just(TransactionHistoryBySection.Section(title: "transacation", items: transactions))
            }

        let transactionHistoryError = transactionHistoryAction.error
            .flatMap { response -> Driver<TransactionHistoryBySection> in
                return Driver.just(TransactionHistoryBySection.Section(title: "transacation", items: []))
            }

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(transactionHistorySuccess)
            .flatMap { list -> Driver<Action<TransactionHistoryBySection>> in
                return Action.makeDriver(Driver.just(list))
            }

        let showActivityIndicator = Driver.merge(initialLoad)
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = Driver.merge(transactionHistorySuccess, transactionHistoryError)
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)
            .flatMap { status in Driver.just(status) }

        let embedEmptyView = transactionHistorySuccess
            .flatMap { [weak self] _ -> Driver<CustomEmptyViewStyle> in
                if (self?.sections.count ?? 0) == 0 {
                    return Driver.just(.transactionListEmpty)
                }
                return Driver.empty()
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            transactionList: transactionHistorySuccess,
            isFetching: refreshAction.isExecuting,
            embedEmptyViewController: embedEmptyView,
            activityIndicator: activityIndicator,
            openTransactionDetailViewController: input.selectedIndexPath
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
