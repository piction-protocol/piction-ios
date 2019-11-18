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
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true

        searchController?.isActive = true

        searchController?.searchBar.placeholder = LocalizedStrings.hint_project_and_tag_search.localized()
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
//        DispatchQueue.main.async {
//            self.searchController?.isActive = true
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
            self?.viewModel?.loadTrigger.onNext(())
        }
    }
}
