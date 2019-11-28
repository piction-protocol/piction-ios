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

protocol HomeSectionDelegate: class {
    func loadComplete()
    func showErrorPopup()
}

final class HomeViewController: UIViewController {
    var disposeBag = DisposeBag()

    let searchResultsController = SearchViewController.make()
    var searchController: UISearchController?
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            scrollView.refreshControl = refreshControl
        }
    }
    @IBOutlet weak var stackView: UIStackView!

    private var loadCompleted = PublishSubject<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()

        searchController = UISearchController(searchResultsController: self.searchResultsController)

        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.dimsBackgroundDuringPresentation = false
        searchController?.searchResultsUpdater = searchResultsController

        navigationItem.searchController = searchController
        if #available(iOS 13, *) {
            navigationItem.hidesSearchBarWhenScrolling = true
        } else {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        definesPresentationContext = true

        searchController?.isActive = true

        searchController?.searchBar.placeholder = LocalizedStrings.hint_project_and_tag_search.localized()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 13, *) {
        } else {
            self.navigationItem.hidesSearchBarWhenScrolling = true
            self.navigationController?.configureNavigationBar(transparent: false, shadow: false)
        }
    }

    private func embedHomeSection() {
        embedHomeTrendingViewController()
        embedHomeSubscriptionViewController()
        embedHomePopularTagsViewController()
        embedHomeNoticeViewController()
    }

    private func removeHomeSection() {
        _ = stackView.arrangedSubviews.map { $0.removeFromSuperview() }
    }

    private func embedHomeTrendingViewController() {
        let vc = HomeTrendingViewController.make()
        vc.delegate = self
        self.addChild(vc)
        self.stackView.addArrangedSubview(vc.view)
        vc.didMove(toParent: self)
    }

    private func embedHomeSubscriptionViewController() {
        let vc = HomeSubscriptionViewController.make()
        vc.delegate = self
        self.addChild(vc)
        self.stackView.addArrangedSubview(vc.view)
        vc.didMove(toParent: self)
    }

    private func embedHomePopularTagsViewController() {
        let vc = HomePopularTagsViewController.make()
        vc.delegate = self
        self.addChild(vc)
        self.stackView.addArrangedSubview(vc.view)
        vc.didMove(toParent: self)
    }

    private func embedHomeNoticeViewController() {
        let vc = HomeNoticeViewController.make()
        vc.delegate = self
        self.addChild(vc)
        self.stackView.addArrangedSubview(vc.view)
        vc.didMove(toParent: self)
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
            loadComplete: loadCompleted.asDriver(onErrorDriveWith: .empty()),
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
            .embedHomeSection
            .drive(onNext: { [weak self] in
                self?.removeHomeSection()
                self?.embedHomeSection()
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

extension HomeViewController: HomeSectionDelegate {
    func loadComplete() {
        self.loadCompleted.onNext(())
    }

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
