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

enum ExplorerBySection {
    case Section(title: String, items: [ExplorerItemType])
}

extension ExplorerBySection: SectionModelType {
    typealias Item = ExplorerItemType

    var items: [ExplorerItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: ExplorerBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum ExplorerItemType {
    case recommendedHeader
    case recommendedProject(project: ProjectModel)
    case noticeHeader
    case notice(notice: BannerModel)
}


final class ExplorerViewController: UIViewController {
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
        searchController?.searchBar.placeholder = "프로젝트 검색"
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

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<ExplorerBySection> {
        return RxTableViewSectionedReloadDataSource<ExplorerBySection>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .recommendedHeader:
                    let cell: ExplorerRecommendedProjectHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                case .recommendedProject(let project):
                    let cell: ExplorerRecommendedProjectTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: project)
                    return cell
                case .noticeHeader:
                    let cell: ExplorerNoticeHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                case .notice(let notice):
                    let cell: ExplorerNoticeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: notice)
                    return cell
                }
            })
    }

    private func openErrorPopup() {
        let alert = UIAlertController(title: "네트워크 오류", message: "서버가 응답하지 않습니다.\n네트워크 환경을 확인해주세요.", preferredStyle: .alert)

        let cancelButton = UIAlertAction(title: "취소", style: .cancel) { _ in
        }
        let okAction = UIAlertAction(title: "재시도", style: .default, handler: { [weak self] action in
            self?.viewModel?.loadTrigger.onNext(())
        })

        alert.addAction(cancelButton)
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }
}

extension ExplorerViewController: ViewModelBindable {
    typealias ViewModel = ExplorerViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = ExplorerViewModel.Input(
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
