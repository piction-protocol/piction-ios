//
//  HomePopularTagsViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/15.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources

final class HomePopularTagsViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    weak var delegate: HomeSectionDelegate?

    private func resizingCollectionViewFlowLayout() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let viewWidth = view.frame.size.width
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && viewWidth == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (viewWidth - 40 - (cellCount - 1) * 7) / cellCount
            let height = width / 1.6
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
            heightConstraint.constant = collectionView.contentSize.height
            titleView.isHidden = collectionView.contentSize.height == 0
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.resizingCollectionViewFlowLayout()
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, HomePopularTagsModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, HomePopularTagsModel>>(
            configureCell: { (_, collectionView, indexPath, model) in
                let cell: HomePopularTagsCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension HomePopularTagsViewController: ViewModelBindable {

    typealias ViewModel = HomePopularTagsViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.dataSource = nil
        collectionView.delegate = nil
        
        let input = HomePopularTagsViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            moreBtnDidTap: moreButton.rx.tap.asDriver(),
            selectedIndexPath: collectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .popularTags
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .popularTags
            .drive(onNext: { [weak self] _ in
                self?.resizingCollectionViewFlowLayout()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .openTagListViewController
            .drive(onNext: { [weak self] indexPath in
                self?.openTagListViewController()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                if let item: HomePopularTagsModel = try? self?.collectionView.rx.model(at: indexPath) {
                    self?.openTagResultProjectViewController(tag: item.tag.name ?? "")
                }
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] _ in
                self?.delegate?.showErrorPopup()
            })
            .disposed(by: disposeBag)
    }
}
