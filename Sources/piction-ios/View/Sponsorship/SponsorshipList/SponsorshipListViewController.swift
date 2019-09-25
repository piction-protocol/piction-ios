//
//  SponsorshipListViewController.swift
//  PictionSDK
//
//  Created by jhseo on 02/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

enum SponsorshipListBySection {
    case Section(title: String, items: [SponsorshipListItemType])
}

extension SponsorshipListBySection: SectionModelType {
    typealias Item = SponsorshipListItemType

    var items: [SponsorshipListItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: SponsorshipListBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum SponsorshipListItemType {
    case button(type: SponsorshipListButtonType)
    case header
    case list(model: SponsorshipModel)
}

final class SponsorshipListViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        if style == .sponsorshipListEmpty {
            emptyView.frame.size.height = 350
        } else {
            emptyView.frame.size.height = getVisibleHeight()
        }
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func openSearchSponsorViewController() {
        let vc = SearchSponsorViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openSponsorshipHistoryViewController() {
        let vc = SponsorshipHistoryViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SponsorshipListBySection> {
        return RxTableViewSectionedReloadDataSource<SponsorshipListBySection>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .button(let type):
                    let cell: SponsorshipListButtonTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(type: type)
                    return cell
                case .header:
                    let cell: SponsorshipListHeaderTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                case .list(let model):
                    let cell: SponsorshipListItemTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                }
        })
    }
}

extension SponsorshipListViewController: ViewModelBindable {
    typealias ViewModel = SponsorshipListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = SponsorshipListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarLine(false)
                self?.navigationController?.navigationBar.prefersLargeTitles = true
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
                self?.navigationController?.hideTransparentNavigationBar()
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarLine(true)
            })
            .disposed(by: disposeBag)

        output
            .sponsorshipList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { $0 }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let `self` = self else { return }
                switch dataSource[indexPath] {
                case .header,
                     .list:
                    break
                case .button(let type):
                    type == .sponsorship ? self.openSearchSponsorViewController() : self.openSponsorshipHistoryViewController()
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
    }
}
