//
//  CategorizedProjectViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/08.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import GSKStretchyHeaderView
import PictionSDK

final class CategorizedProjectViewController: UIViewController {
    var disposeBag = DisposeBag()

    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))
    private var stretchyHeader: CategorizedProjectHeaderView?

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            stretchyHeader = CategorizedProjectHeaderView.getView()
            if let stretchyHeader = stretchyHeader {
                stretchyHeader.stretchDelegate = self
                collectionView.addSubview(stretchyHeader)
            }
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .footer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        emptyView.frame.size.height = visibleHeight
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
                let cell: CategorizedProjectListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }
                if (kind == UICollectionView.elementKindSectionFooter) {
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .footer)

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        stretchyHeader?.frame.size.width = view.frame.size.width
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

extension CategorizedProjectViewController: ViewModelBindable {
    typealias ViewModel = CategorizedProjectViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = CategorizedProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath:
            collectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.navigationController?.navigationBar.barStyle = .black
                self?.navigationController?.navigationBar.tintColor = .white
                self?.setInfiniteScrollStyle()
                let categoryId = self?.viewModel?.categoryId ?? 0
                FirebaseManager.screenName("카테고리상세_\(categoryId)")
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
            })
            .disposed(by: disposeBag)

        output
            .categoryInfo
            .drive(onNext: { [weak self] categoryInfo in
                self?.stretchyHeader?.configureCategoryInfo(with: categoryInfo)
            })
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

extension CategorizedProjectViewController: UICollectionViewDelegateFlowLayout {
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


// MARK: - GSKStretchyHeaderViewStretchDelegate
extension CategorizedProjectViewController: GSKStretchyHeaderViewStretchDelegate {
    func stretchyHeaderView(_ headerView: GSKStretchyHeaderView, didChangeStretchFactor stretchFactor: CGFloat) {
        stretchyHeader?.maskImage.isHidden = false
        if stretchFactor > 0.1 {
            stretchyHeader?.maskImage.blurRadius = 0
        } else {
//            print((1 - min(1, stretchFactor)) - 90 / 10)
            stretchyHeader?.maskImage.blurRadius = (1 - min(1, stretchFactor) - 0.9) * 50
        }
    }
}
