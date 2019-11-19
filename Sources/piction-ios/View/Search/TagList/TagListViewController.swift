//
//  TagListViewController.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class TagListViewController: UITableViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = getVisibleHeight()
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func openTagResultProjectViewController(tag: String) {
        let vc = TagResultProjectViewController.make(tag: tag)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, TagModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, TagModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: TagListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension TagListViewController: ViewModelBindable {
    typealias ViewModel = TagListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = TagListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath:
            tableView.rx.itemSelected.asDriver()
        )

        tableView.dataSource = nil
        tableView.delegate = nil

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                FirebaseManager.screenName("태그")
            })
            .disposed(by: disposeBag)

        output
            .tagList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .tagList
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .openTagResultProjectViewController
            .drive(onNext: { [weak self] indexPath in
                if let item: TagModel = try? self?.tableView.rx.model(at: indexPath) {
                    self?.openTagResultProjectViewController(tag: item.name ?? "")
                }
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
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
