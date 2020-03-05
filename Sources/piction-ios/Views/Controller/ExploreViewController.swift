//
//  ExploreViewController.swift
//  PictionView
//
//  Created by jhseo on 25/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import PictionSDK

// MARK: - UIViewController
final class ExploreViewController: UIViewController {
    var disposeBag = DisposeBag()

    let searchResultsController = SearchViewController.make()
    var searchController: UISearchController?
    var exploreHeaderView: CategoryListViewController?
    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))

    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            // pull to refresh 추가
            collectionView.refreshControl = refreshControl
            // ProjectListCollectionViewCell은 공통으로 사용하여 storyboard가 아닌 여기서 등록
            collectionView.registerXib(ProjectListCollectionViewCell.self)
            // collectionView header 추가
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .header)
            // collectionView footer 추가
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .footer)
            // UI가 완전히 보여지기 전까지는 숨김
            collectionView.isHidden = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // emptyView의 height를 보여지는 화면의 height로 설정
        emptyView.frame.size.height = visibleHeight

        self.configureSearchController()
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ExploreViewController: ViewModelBindable {
    typealias ViewModel = ExploreViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = ExploreViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewDidAppear: rx.viewDidAppear.asDriver(), // 화면이 보여질 때
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            selectedIndexPath: collectionView.rx.itemSelected.asDriver(), // collectionView의 item을 눌렀을 때
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver() // pull to refresh 액션 시
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.collectionView.setInfiniteScrollStyle()
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
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.collectionView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 카테고리 리스트 embed
        output
            .embedCategoryListViewController
            .drive(onNext: { [weak self] in
                self?.embedCategoryListViewController()
            })
            .disposed(by: disposeBag)

        // 프로젝트 리스트를 collectionView에 출력
        output
            .projectList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 프로젝트 리스트를 출력 후 infiniteScroll 로딩 해제
        output
            .projectList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
                self?.collectionView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        // collectionView의 item 선택 시 project 화면으로 push
        output
            .selectedIndexPath
            .map { dataSource[$0].uri }
            .flatMap(Driver.from)
            .map { .project(uri: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
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

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.collectionView.finishInfiniteScroll() // infiniteScroll 로딩 중이면 로딩 해제
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - CategoryListViewDelegate
extension ExploreViewController: CategoryListViewDelegate {
    // categoryList의 로딩이 완료되면 collectionView를 리로딩하고 collectionView를 숨김해제 함
    func loadComplete() {
        collectionView.reloadData()
        collectionView.isHidden = false
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ExploreViewController: UICollectionViewDelegateFlowLayout {
    // header size 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

        guard let headerCollectionView = exploreHeaderView?.collectionView else { return CGSize(width: view.frame.size.width, height: 50) }
        let width = view.frame.size.width
        let height = headerCollectionView.contentSize.height
        return CGSize(width: width, height: height)
    }

    // footer size 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if self.emptyView.subviews.count > 0 {
            return CGSize(width: SCREEN_W, height: emptyView.frame.size.height)
        } else {
            return CGSize.zero
        }
    }

    // 각 section의 padding 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.emptyView.subviews.count > 0 {
            return UIEdgeInsets.zero
        } else {
            return UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        }
    }
}

// MARK: - DataSource
extension ExploreViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // header, footer 설정
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }

                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .header)

                    // subview가 없는 경우에만 header를 embed
                    if reusableView.subviews.isEmpty {
                        if let exploreHeaderView = self.exploreHeaderView {
                            self.embed(exploreHeaderView, to: reusableView)
                        }
                    }
                    reusableView.layoutIfNeeded()
                    return reusableView
                case UICollectionView.elementKindSectionFooter:
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .footer)

                    // subview를 모두 제거 하고 emptyView를 add
                    _ = reusableView.subviews.map { $0.removeFromSuperview() }
                    reusableView.addSubview(self.emptyView)
                    return reusableView
                default:
                    return UICollectionReusableView()
                }
            })
    }
}

// MARK: - Private Method
extension ExploreViewController {
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

    // 카테고리 목록을 header에 embed
    private func embedCategoryListViewController() {
        self.exploreHeaderView = CategoryListViewController.make()
        self.exploreHeaderView?.delegate = self
    }

    // Pad에서 가로/세로모드 변경 시 cell size 변경 (pad 가로모드에서는 한줄에 4개의 cell을 보여주도록 함)
    private func changeLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }
}
