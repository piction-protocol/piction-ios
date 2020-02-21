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
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.tableView.layoutIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tableView.setInfiniteScrollStyle()
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

        self.searchController?.searchBar.placeholder = LocalizationKey.hint_project_and_tag_search.localized()
    }

    func openSearchBar() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.searchController?.searchBar.becomeFirstResponder()
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<HomeSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<HomeSection>>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .header(let type):
                    let cell: HomeHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: type)
                    return cell
                case .subscribingPosts(let model):
                    let cell: HomeSubscribingPostsTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .trending(let model):
                    let cell: HomeTrendingTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    cell.layoutIfNeeded()
                    return cell
                }
        })
    }
}

extension HomeViewController: ViewModelBindable {
    typealias ViewModel = HomeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = HomeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        output
            .homeSection
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .homeSection
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .subscribingPosts(let item):
                    guard
                        let postId = item.id,
                        let uri = item.project?.uri,
                        let index = self?.navigationController?.viewControllers.count
                    else { return }

                    self?.openPostViewController(uri: uri, postId: postId)

                    let backgroundProject = ProjectViewController.make(uri: uri)
                    self?.navigationController?.viewControllers.insert(backgroundProject, at: index)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}

extension HomeViewController {
    func showErrorPopup() {
        Toast.loadingActivity(false)
        showPopup(
            title: LocalizationKey.popup_title_network_error.localized(),
            message: LocalizationKey.msg_api_internal_server_error.localized(),
            action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
            self?.viewModel?.loadRetryTrigger.onNext(())
        }
    }
}
