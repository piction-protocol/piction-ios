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

// MARK: - UIViewController
final class HomeViewController: UIViewController {
    var disposeBag = DisposeBag()

    let searchResultsController = SearchViewController.make()
    var searchController: UISearchController?
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            // pull to refresh 추가
            tableView.refreshControl = refreshControl
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // searchController 설정
        self.configureSearchController()
        // 스토어 리뷰 팝업 설정
        StoreReviewManager().askForReview(navigationController: self.navigationController)
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension HomeViewController: ViewModelBindable {
    typealias ViewModel = HomeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        tableView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = HomeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewDidAppear: rx.viewDidAppear.asDriver(), // 화면이 보여질 때
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver() // pull to refresh 액션 시
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 화면이 보여질 때
        output
            .viewDidAppear
            .drive(onNext: { [weak self] in
                // iOS 13 이전 버전에서는 화면이 보여질 때 navigation설정을 다시 해줘야 함
                if #available(iOS 13, *) {
                } else {
                    self?.navigationItem.hidesSearchBarWhenScrolling = true
                    self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                }
            })
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.tableView.layoutIfNeeded()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // section의 테이터를 tableView에 출력
        output
            .homeSection
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // section의 테이터를 출력 후 infiniteScroll 로딩 해제
        output
            .homeSection
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        // tableView의 row를 선택할 때
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

                    self?.openView(type: .post(uri: uri, postId: postId), openType: .push)

                    let backgroundProject = ProjectViewController.make(uri: uri)
                    self?.navigationController?.viewControllers.insert(backgroundProject, at: index)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        // pull to refresh 로딩 및 해제
        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension HomeViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<HomeSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<HomeSection>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .header(let type):
                    let cell: HomeHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: type)
                    return cell
                case .subscribingPosts(let model):
                    var isLargeType: Bool { // 카테고리에 따라 라지타입으로 출력해야 함
                        guard
                            model.cover != nil,
                            let categories = model.project?.categories,
                            (categories.filter { ($0.name ?? "") == "일러스트" || ($0.name ?? "") == "웹툰" || ($0.name ?? "") == "사진" || ($0.name ?? "") == "영상" }.count) > 0
                            else { return false }
                        return true
                    }
                    if isLargeType {
                        let cell: HomeSubscribingPostsLargeTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                        cell.configure(with: model)
                        return cell
                    } else {
                        let cell: HomeSubscribingPostsSmallTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                        cell.configure(with: model)
                        return cell
                    }
                case .trending(let model):
                    let cell: HomeTrendingTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    cell.layoutIfNeeded()
                    return cell
                }
        })
    }
}

// MARK: - Private Method
extension HomeViewController {
    // searchController 설정
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
}

// MARK: - Public Method
extension HomeViewController {
    // deeplink를 통해 searchBar를 열어야 할 때 사용
    func openSearchBar() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.searchController?.searchBar.becomeFirstResponder()
        }
    }
}
