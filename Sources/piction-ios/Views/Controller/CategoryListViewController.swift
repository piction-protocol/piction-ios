//
//  CategoryListViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/09.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

protocol CategoryListViewDelegate: class {
    func loadComplete()
}

final class CategoryListViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var collectionView: UICollectionView!

    weak var delegate: CategoryListViewDelegate?

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: CategoryListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                cell.layoutIfNeeded()
                return cell
            })
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width / 2
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }
}

extension CategoryListViewController: ViewModelBindable {
    typealias ViewModel = CategoryListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CategoryListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: collectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .categoryList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .categoryList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let id = dataSource[indexPath].id else { return }
                self?.openCategorizedProjectViewController(id: id)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.collectionView.finishInfiniteScroll()
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: LocalizationKey.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)
    }
}
