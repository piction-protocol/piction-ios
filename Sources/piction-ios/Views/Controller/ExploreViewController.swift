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

final class ExploreViewController: UIViewController {
    var disposeBag = DisposeBag()

    var exploreHeaderView: CategoryListViewController?
    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))

    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.refreshControl = refreshControl
            collectionView.registerXib(ProjectListCollectionViewCell.self)
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .header)
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .footer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        emptyView.frame.size.height = visibleHeight
    }

    private func embedCategoryListViewController() {
        self.exploreHeaderView = CategoryListViewController.make()
        self.exploreHeaderView?.delegate = self
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(

            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }

                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .header)

                    if reusableView.subviews.isEmpty {
                        if let exploreHeaderView = self.exploreHeaderView {
                            self.embed(exploreHeaderView, to: reusableView)
                        }
                    }
                    reusableView.layoutIfNeeded()
                    return reusableView
                case UICollectionView.elementKindSectionFooter:
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .footer)

                    _ = reusableView.subviews.map { $0.removeFromSuperview() }
                    reusableView.addSubview(self.emptyView)
                    return reusableView
                default:
                    return UICollectionReusableView()
                }
            })
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setInfiniteScrollStyle()
    }

    private func setInfiniteScrollStyle() {
        if #available(iOS 12.0, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                collectionView.infiniteScrollIndicatorStyle = .white
            } else {
                collectionView.infiniteScrollIndicatorStyle = .gray
            }
        }
    }
}

extension ExploreViewController: ViewModelBindable {
    typealias ViewModel = ExploreViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = ExploreViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath:
            collectionView.rx.itemSelected.asDriver(),
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        output
            .embedCategoryListViewController
            .drive(onNext: { self.embedCategoryListViewController() })
            .disposed(by: disposeBag)

        output
            .projectList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .projectList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
                self?.collectionView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let uri = dataSource[indexPath].uri else { return }
                self?.openProjectViewController(uri: uri)
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

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.collectionView.finishInfiniteScroll()
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizedStrings.popup_title_network_error.localized(),
                    message: LocalizedStrings.msg_api_internal_server_error.localized(),
                    action: LocalizedStrings.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)
    }
}

extension ExploreViewController: CategoryListViewDelegate {
    func loadComplete() {
        collectionView.reloadData()
    }
}

extension ExploreViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

        guard let headerCollectionView = exploreHeaderView?.collectionView else { return CGSize(width: view.frame.size.width, height: 50) }
        let width = view.frame.size.width
        let height = headerCollectionView.contentSize.height
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if self.emptyView.subviews.count > 0 {
            return CGSize(width: SCREEN_W, height: emptyView.frame.size.height)
        } else {
            return CGSize.zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.emptyView.subviews.count > 0 {
            return UIEdgeInsets.zero
        } else {
            return UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        }
    }
}
