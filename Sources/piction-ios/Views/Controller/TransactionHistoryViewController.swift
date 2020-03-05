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

// MARK: - UITableViewController
final class TransactionHistoryViewController: UITableViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension TransactionHistoryViewController: ViewModelBindable {
    typealias ViewModel = TransactionHistoryViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        // UITableViewController의 경우 UITableViewDelegate, UITableViewDataSource가 자동으로 적용되므로 사용하지 않으면 제거
        tableView.dataSource = nil
        tableView.delegate = nil

        let input = TransactionHistoryViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            refreshControlDidRefresh: refreshControl!.rx.controlEvent(.valueChanged).asDriver(), // pull to refresh 액션 시
            selectedIndexPath: tableView.rx.itemSelected.asDriver() // tableView의 row를 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // transaction 목록의 데이터를 tableView에 출력
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

        // transaction 목록의 테이터를 출력 후 infiniteScroll 로딩 해제
        output
            .transactionList
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        // pull to refresh 로딩 및 해제
        output
            .isFetching
            .drive(refreshControl!.rx.isRefreshing)
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // tableView의 row를 선택할 때
        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .list(let transaction, _):
                    // transaction 상세 화면으로 push
                    self?.openView(type: .transactionDetail(transaction: transaction), openType: .push)
                default:
                    return
                }
            })
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.tableView.finishInfiniteScroll() // infiniteScroll 로딩 중이면 로딩 해제
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension TransactionHistoryViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<TransactionHistorySection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<TransactionHistorySection>>(
            // cell 설정
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
    }
}

// MARK: - Private Method
extension TransactionHistoryViewController {
    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
