//
//  TransactionDetailViewController.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import SafariServices
import PictionSDK

final class TransactionDetailViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<TransactionDetailSection>> {
        let dataSource = RxTableViewSectionedReloadDataSource<SectionType<TransactionDetailSection>>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .info(let model):
                    let cell: TransactionDetailInfoTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .header(let model):
                    let cell: TransactionDetailHeaderTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .list(let model):
                    let cell: TransactionDetailItemTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .footer:
                    let cell: TransactionDetailFooterTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                }
        })
        return dataSource
    }
}

extension TransactionDetailViewController: ViewModelBindable {
    typealias ViewModel = TransactionDetailViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = TransactionDetailViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath:
            tableView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .navigationTitle
            .drive(onNext: { [weak self] title in
                self?.navigationItem.title = title
            })
            .disposed(by: disposeBag)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .transactionInfo
            .do(onNext: { [weak self] _ in
                let view = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: SCREEN_H))
                if #available(iOS 13.0, *) {
                    view.backgroundColor = .secondarySystemBackground
                } else {
                    view.backgroundColor = UIColor(r: 250, g: 250, b: 250)
                }
                self?.emptyView.addSubview(view)
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .list(_, _, let link):
                    if let url = URL(string: link) {
                        let safariViewController = SFSafariViewController(url: url)
                        self?.present(safariViewController, animated: true, completion: nil)
                    }
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizedStrings.popup_title_network_error.localized(),
                    message: LocalizedStrings.msg_api_internal_server_error.localized(),
                    action: LocalizedStrings.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)
    }
}
