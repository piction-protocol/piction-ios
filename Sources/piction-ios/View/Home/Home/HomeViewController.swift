//
//  HomeViewController.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class HomeViewController: UIViewController {
    var disposeBag = DisposeBag()

    let searchResultsController = SearchViewController.make()
    var searchController: UISearchController?
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.refreshControl = refreshControl
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureSearchController()

        StoreReviewManager().askForReview(navigationController: self.navigationController)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 13, *) {
        } else {
            self.navigationItem.hidesSearchBarWhenScrolling = true
            self.navigationController?.configureNavigationBar(transparent: false, shadow: false)
        }
    }

    private func configureSearchController() {
        self.searchController = UISearchController(searchResultsController: self.searchResultsController)

        self.searchController?.hidesNavigationBarDuringPresentation = true
        self.searchController?.dimsBackgroundDuringPresentation = false
        self.searchController?.searchResultsUpdater = self.searchResultsController

        self.navigationItem.searchController = self.searchController
        if #available(iOS 13, *) {
            self.navigationItem.hidesSearchBarWhenScrolling = true
        } else {
            self.navigationItem.hidesSearchBarWhenScrolling = false
        }
        self.definesPresentationContext = true

        self.searchController?.isActive = true

        self.searchController?.searchBar.placeholder = LocalizedStrings.hint_project_and_tag_search.localized()
    }

    func openSearchBar() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.searchController?.searchBar.becomeFirstResponder()
        }
    }
}

extension HomeViewController: ViewModelBindable {
    typealias ViewModel = HomeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = HomeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.searchResultsController.setKeyboardDelegate()
                FirebaseManager.screenName("홈")
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)
    }
}

extension HomeViewController {
    func showErrorPopup() {
        Toast.loadingActivity(false)
        showPopup(
            title: LocalizedStrings.popup_title_network_error.localized(),
            message: LocalizedStrings.msg_api_internal_server_error.localized(),
            action: LocalizedStrings.retry.localized()) { [weak self] in
            self?.viewModel?.loadRetryTrigger.onNext(())
        }
    }
}
