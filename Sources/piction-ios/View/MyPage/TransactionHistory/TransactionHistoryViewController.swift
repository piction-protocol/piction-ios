//
//  TransactionHistoryViewController.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import PictionSDK

enum TransactionHistoryBySection {
    case Section(title: String, items: [TransactionHistoryItemType])
}

extension TransactionHistoryBySection: SectionModelType {
    typealias Item = TransactionHistoryItemType

    var items: [TransactionHistoryItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: TransactionHistoryBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum TransactionHistoryItemType {
    case header
    case year(model: String)
    case list(model: TransactionModel, dateTitle: Bool)
    case footer
}

final class TransactionHistoryViewController: UITableViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = getVisibleHeight()
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func openTransactionDetailViewController(transaction: TransactionModel) {
        let vc = TransactionDetailViewController.make(transaction: transaction)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<TransactionHistoryBySection> {
        let dataSource = RxTableViewSectionedReloadDataSource<TransactionHistoryBySection>(
            configureCell: { (dataSource, tableView, indexPath, model) in
                switch dataSource[indexPath] {
                case .header:
                    let cell: TransactionHistoryHeaderTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                case .year(let model):
                    let cell: TransactionHistoryYearTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .list(let model, let dateTitle):
                    let cell: TransactionHistoryListTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model, dateTitle: dateTitle)
                    return cell
                case .footer:
                    let cell: TransactionHistoryFooterTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                }
            })
        return dataSource
    }
}

extension TransactionHistoryViewController: ViewModelBindable {

    typealias ViewModel = TransactionHistoryViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadTrigger.onNext(())
        }
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = TransactionHistoryViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            refreshControlDidRefresh: refreshControl!.rx.controlEvent(.valueChanged).asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.navigationBar.prefersLargeTitles = false
            })
            .disposed(by: disposeBag)

        output
            .transactionList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .transactionList
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl!.rx.isRefreshing)
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        output
            .openTransactionDetailViewController
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .list(let model, _):
                    self?.openTransactionDetailViewController(transaction: model)
                default:
                    return
                }
            })
            .disposed(by: disposeBag)


        output
            .activityIndicator
            .drive(onNext: { [weak self] status in
                if status {
                    self?.view.makeToastActivity(.center)
                } else {
                    self?.view.hideToastActivity()
                }
            })
            .disposed(by: disposeBag)
    }
}

