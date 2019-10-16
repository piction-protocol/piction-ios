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
import SafariServices
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
    case recommendedHeader
    case recommendedProject(project: ProjectModel)
    case noticeHeader
    case notice(notice: BannerModel)
}


final class HomeViewController: UIViewController {
    var disposeBag = DisposeBag()

    let searchResultsController = SearchProjectViewController.make()
    var searchController: UISearchController?
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.refreshControl = refreshControl
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchController = UISearchController(searchResultsController: self.searchResultsController)

        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.dimsBackgroundDuringPresentation = false
        searchController?.searchBar.placeholder = LocalizedStrings.hint_project_search.localized()
        searchController?.searchResultsUpdater = searchResultsController

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<HomeBySection> {
        return RxTableViewSectionedReloadDataSource<HomeBySection>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .recommendedHeader:
                    let cell: HomeRecommendedProjectHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                case .recommendedProject(let project):
                    let cell: HomeRecommendedProjectTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: project)
                    return cell
                case .noticeHeader:
                    let cell: HomeNoticeHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                case .notice(let notice):
                    let cell: HomeNoticeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: notice)
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
            self.searchController?.searchBar.becomeFirstResponder()
        }
    }
}

extension HomeViewController: ViewModelBindable {
    typealias ViewModel = HomeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = HomeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath:
            tableView.rx.itemSelected.asDriver(),
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
            .projectList
            .do(onNext: { [weak self] _ in
                self?.navigationItem.hidesSearchBarWhenScrolling = true
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .openProjectViewController
            .drive(onNext: { [weak self] indexPath in
                self?.searchController?.isActive = false
                switch dataSource[indexPath] {
                case .recommendedProject(let project):
                    self?.openProjectViewController(uri: project.uri ?? "")
                case .notice(let notice):
                    guard let url = URL(string: notice.link ?? "") else { return }
                    let safariViewController = SFSafariViewController(url: url)
                    self?.present(safariViewController, animated: true, completion: nil)
                default:
                    return
                }
//                if let item: ProjectModel = try? self?.table.rx.model(at: indexPath) {
//                    self?.openProjectViewController(uri: item.uri ?? "")
//                }
            })
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
