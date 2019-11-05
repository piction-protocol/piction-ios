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

enum HomeBySection {
    case Section(title: String, items: [HomeItemType])
}

extension HomeBySection: SectionModelType {
    typealias Item = HomeItemType

    var items: [HomeItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: HomeBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum HomeItemType {
    case header(model: HomeHeaderType)
    case trending(model: [ProjectModel])
    case subscription(projects: [ProjectModel], posts: [PostModel])
    case popularTag(tags: [TagModel], thumbnails: [String])
    case notice(model: [BannerModel])
}

final class HomeViewController: UIViewController {
    var disposeBag = DisposeBag()

    let searchResultsController = SearchViewController.make()
    var searchController: UISearchController?
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.refreshControl = refreshControl
            tableView.rowHeight = 0
            tableView.estimatedRowHeight = UITableView.automaticDimension
        }
    }

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.tableView.reloadData()
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<HomeBySection> {
        return RxTableViewSectionedReloadDataSource<HomeBySection>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .header(let info):
                    let cell: HomeHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: info)
                    cell.layoutSubviews()
                    return cell
                case .trending(let projects):
                    let cell: HomeTrendingSectionTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: projects)
                    cell.layoutSubviews()
                    return cell
                case .subscription(let projects, let posts):
                    let cell: HomeSubscriptionSectionTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(projects: projects, posts: posts)
                    cell.layoutSubviews()
                    return cell
                case .popularTag(let tags, let thumbnails):
                    let cell: HomePopularTagSectionTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(tags: tags, thumbnails: thumbnails)
                    cell.layoutSubviews()
                    return cell
                case .notice(let notices):
                    let cell: HomeNoticeSectionTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: notices)
                    cell.layoutSubviews()
                    return cell
                }
            })
    }

    private func openErrorPopup() {
        let alert = UIAlertController(title: LocalizedStrings.popup_title_network_error.localized(), message: LocalizedStrings.msg_api_internal_server_error.localized(), preferredStyle: .alert)

        let cancelButton = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel) { _ in
        }
        let okAction = UIAlertAction(title: LocalizedStrings.retry.localized(), style: .default, handler: { [weak self] action in
            self?.viewModel?.loadTrigger.onNext(())
        })

        alert.addAction(cancelButton)
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
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
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

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
            })
            .disposed(by: disposeBag)

        output
            .sectionList
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .openErrorPopup
            .drive(onNext: { [weak self] in
                self?.openErrorPopup()
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
