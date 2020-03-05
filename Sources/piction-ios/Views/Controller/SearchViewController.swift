//
//  SearchViewController.swift
//  PictionView
//
//  Created by jhseo on 09/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// MARK: - UIViewController
final class SearchViewController: UIViewController {
    var disposeBag = DisposeBag()

    private let searchText = PublishSubject<String>()
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SearchViewController: ViewModelBindable {
    typealias ViewModel = SearchViewModel

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

        let input = SearchViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            searchText: searchText.asDriver(onErrorDriveWith: .empty()).throttle(0.5), // 검색 text를 입력했을 때
            segmentedControlDidChange: segmentedControl.rx.selectedSegmentIndex.asDriver(), // segmentedControll을 변경했을 때
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            contentOffset: tableView.rx.contentOffset.asDriver() // tableView의 contentOffset이 변경되었을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // segmentControl 값에 따라 searchBar의 placeholder 설정
        output
            .setPlaceHolder
            .drive(onNext: { menu in
                if menu == 0 {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizationKey.hint_project_search.localized()
                } else {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizationKey.hint_tag_search.localized()
                }
            })
            .disposed(by: disposeBag)

        // 화면이 사라지기 전에 placeHolder를 변경
        output
            .viewWillDisappear
            .drive(onNext: { _ in
                UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizationKey.hint_project_and_tag_search.localized()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // segmentControl의 값 변경 시
        output
            .menuChanged
            .drive(onNext: { menu in
                if menu == 0 {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizationKey.hint_project_search.localized()
                } else {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizationKey.hint_tag_search.localized()
                }
            })
            .disposed(by: disposeBag)

        // 검색 결과를 tableView에 출력
        output
            .searchList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 검색 결과를 출력 후 infiniteScroll 로딩 해제
        output
            .searchList
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
                case .project(let project): // 현재 dataSource가 project의 data이면
                    guard let uri = project.uri else { return }
                    self?.openView(type: .project(uri: uri), openType: .push)
                case .tag(let tag): // 현재 dataSource가 tag의 data이면
                    self?.openView(type: .taggingProject(tag: tag.name ?? ""), openType: .push)
                }
            })
            .disposed(by: disposeBag)

        // 결과가 없으면 emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // 화면을 닫고 searchBar 초기화
        output
            .dismissViewController
            .drive(onNext: { _ in
                UIApplication.topViewController()?.navigationItem.searchController?.searchBar.text = nil
                UIApplication.topViewController()?.navigationItem.searchController?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UISearchResultsUpdating
extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchController.searchResultsController?.view.isHidden = false
        guard let text = searchController.searchBar.text else { return }
        self.searchText.onNext(text)
    }
}

// MARK: - DataSource
extension SearchViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<SearchSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<SearchSection>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .project(let project): // 현재 dataSource가 project의 data이면
                    let cell: SearchProjectTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: project)
                    return cell
                case .tag(let tag): // 현재 dataSource가 tag의 data이면
                    let cell: SearchTagTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: tag)
                    return cell
                }
        })
    }
}

// MARK: - Private Method
extension SearchViewController {
    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
