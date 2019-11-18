//
//  SubscriptionListViewController.swift
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

final class SubscriptionListViewController: UIViewController {
    var disposeBag = DisposeBag()

    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        emptyView.frame.size.height = getVisibleHeight()
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
        self.collectionView.reloadData()
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: SubscriptionListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        },
        configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
            guard let `self` = self else { return UICollectionReusableView() }
            if (kind == UICollectionView.elementKindSectionFooter) {
                let reusableView = collectionView.dequeueReusableView(SubscriptionListCollectionFooterView.self, indexPath: indexPath, kind: .footer)

                _ = reusableView.subviews.map { $0.removeFromSuperview() }
                reusableView.addSubview(self.emptyView)
                return reusableView
            }
            return UICollectionReusableView()
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

extension SubscriptionListViewController: ViewModelBindable {
    typealias ViewModel = SubscriptionListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadTrigger.onNext(())
        }
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SubscriptionListViewModel.Input(
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
                FirebaseManager.screenName("구독")
            })
            .disposed(by: disposeBag)

        output
            .subscriptionList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.collectionView.refreshControl = self?.refreshControl
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .subscriptionList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
                self?.collectionView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                self?.collectionView.refreshControl = nil
                self?.collectionView.contentOffset = CGPoint(x: 0, y: -LARGE_NAVIGATION_HEIGHT)
                self?.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        output
            .openProjectViewController
            .drive(onNext: { [weak self] project in
                self?.openProjectViewController(uri: project.uri ?? "")
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)
    }
}

extension SubscriptionListViewController: UICollectionViewDelegateFlowLayout {
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

