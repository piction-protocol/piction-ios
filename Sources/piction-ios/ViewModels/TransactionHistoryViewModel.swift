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

// MARK: - TransactionHistorySection
enum TransactionHistorySection {
    case header
    case year(model: String)
    case list(model: TransactionModel, dateTitle: Bool)
    case footer
}

// MARK: - ViewModel
final class TransactionHistoryViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager) = dependency
    }

    var page = 0
    var sections: [TransactionModel] = []
    var shouldInfiniteScroll = true

    var loadRetryTrigger = PublishSubject<Void>()
    var loadNextTrigger = PublishSubject<Void>()
}

// MARK: - Input & Output
extension TransactionHistoryViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let transactionList: Driver<SectionType<TransactionHistorySection>>
        let isFetching: Driver<Bool>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }
}

// MARK: - ViewModel Build
extension TransactionHistoryViewModel {
    func build(input: Input) -> Output {
        let firebaseManager = self.firebaseManager

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("마이페이지_거래내역")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // pull to refresh 액션 시
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        // 최초 진입 시, pull to refresh 액션 시
        let initialPage = Driver.merge(initialLoad, refreshControlDidRefresh)
            .do(onNext: { [weak self] in
                // 데이터 초기화
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, pull to refresh 액션 시, infinite scroll로 다음 페이지 호출, 새로고침 필요 시
        // transaction 목록 호출
        let transactionHistoryAction = Driver.merge(initialPage, loadNext, loadRetry)
            .map { WalletAPI.transactions(page: self.page + 1, size: 30) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // transaction 목록 호출 성공 시
       let transactionHistorySuccess = transactionHistoryAction.elements
            .map { try? $0.map(to: PageViewResponse<TransactionModel>.self) }
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList?.pageable?.pageNumber,
                    let totalPages = pageList?.totalPages
                else { return }

                // 페이지 증가
                self.page = self.page + 1

                // 현재 페이지가 전체페이지보다 작을때만 infiniteScroll 동작
                self.shouldInfiniteScroll = pageNumber < totalPages - 1
            })
            .map { self.sections.append(contentsOf: $0?.content ?? []) }
            .map { [weak self] _ -> [TransactionHistorySection] in
                guard let `self` = self else { return [] }
                var transactions: [TransactionHistorySection] = []

                // 년도로 그룹핑
                let yearGroup = self.groupedBy(self.sections, dateComponents: [.year])

                for (index, element) in yearGroup.sorted(by: { $0.0 > $1.0 }).enumerated() {
                    if index != 0 {
                        // 년도 헤더 추가
                        transactions.append(contentsOf: [.year(model: element.key.toString(format: "YYYY"))])
                    }
                    // 일자별 그룹핑
                    let dayGroup = self.groupedBy(element.value, dateComponents: [.year, .month, .day])
                    for item in dayGroup.sorted(by: { $0.0 > $1.0 }) {
                        // header 공간 추가
                        transactions.append(contentsOf: [.header])

                        // transaction section 추가
                        let transaction: [TransactionHistorySection] = (item.value).enumerated().map { .list(model: $1, dateTitle: $0 == 0) }
                        transactions.append(contentsOf: transaction)

                        // footer line 추가
                        transactions.append(contentsOf: [.footer])
                    }
                }
                return transactions
            }
            .map { SectionType<TransactionHistorySection>.Section(title: "transacation", items: $0) }

        // transaction 목록 호출 에러 시 empty list
        let transactionHistoryEmptyList = transactionHistoryAction.error
            .map { _ in SectionType<TransactionHistorySection>.Section(title: "transacation", items: []) }

        // transaction 목록 호출 에러 시 unauthorized가 아닐 때
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

        // transaction 목록
        let transactionHistoryList = Driver.merge(transactionHistorySuccess, transactionHistoryEmptyList)

        // 에러 팝업 출력
        let showErrorPopup = transactionHistoryListError

        // pull to refresh 로딩 및 해제
        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(transactionHistorySuccess)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        // 최초 진입 시, pull to refresh 액션 시
        // 로딩 뷰 출력
        let showActivityIndicator = initialPage
            .map { true }

        // transaction 목록 불러오면
        // 로딩 뷰 해제
        let hideActivityIndicator = transactionHistoryList
            .map { _ in false }

        // 로딩 뷰
        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        let embedEmptyViewController = transactionHistorySuccess
            .filter { $0.items.isEmpty }
            .map { _ in .transactionListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        return Output(
            viewWillAppear: viewWillAppear,
            traitCollectionDidChange: input.traitCollectionDidChange,
            transactionList: transactionHistorySuccess,
            isFetching: refreshAction.isExecuting,
            embedEmptyViewController: embedEmptyViewController,
            selectedIndexPath: input.selectedIndexPath,
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
