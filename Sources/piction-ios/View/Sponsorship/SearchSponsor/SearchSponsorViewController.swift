//
//  SearchSponsorViewController.swift
//  PictionSDK
//
//  Created by jhseo on 19/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import ViewModelBindable
import PictionSDK

final class SearchSponsorViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!

    let searchController = UISearchController(searchResultsController: nil)

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, UserModel>> {
        let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, UserModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: SearchSponsorTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
        return dataSource
    }

    private func openSendDonationViewController(loginId: String) {
        let vc = SendDonationViewController.make(loginId: loginId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.searchBar.becomeFirstResponder()
    }
}

extension SearchSponsorViewController: ViewModelBindable {
    typealias ViewModel = SearchSponsorViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = SearchSponsorViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            searchText: searchBar.rx.text.orEmpty.asDriver().throttle(0.5),
            selectedIndexPath: tableView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.navigationController?.navigationBar.prefersLargeTitles = false
                self.navigationController?.setNavigationBarLine(false)
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarLine(true)
            })
            .disposed(by: disposeBag)

        output
            .userList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .openSendDonationViewController
            .drive(onNext: { [weak self] indexPath in
                self?.searchBar.resignFirstResponder()
                let loginId = dataSource[indexPath].loginId ?? ""
                self?.openSendDonationViewController(loginId: loginId)
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

extension SearchSponsorViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
}
