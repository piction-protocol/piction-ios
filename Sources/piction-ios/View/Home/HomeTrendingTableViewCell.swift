//
//  HomeTrendingTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/12/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import PictionSDK

final class HomeTrendingTableViewCell: ReuseTableViewCell {
    var disposeBag = DisposeBag()

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    typealias Model = [ProjectModel]

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let viewWidth = UIApplication.topViewController()?.view.frame.size.width ?? 0
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && viewWidth == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (viewWidth - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            if collectionView.contentSize.height > 0 {
                heightConstraint.constant = collectionView.contentSize.height
            } else {
                heightConstraint.constant = height + 40
            }
            collectionView.layoutIfNeeded()
        }
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: HomeTrendingCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            })
    }

    func configure(with model: Model) {
        collectionView.dataSource = nil
        collectionView.delegate = nil

        let dataSource = configureDataSource()
        Observable.just(model)
            .map { [SectionModel(model: "trending", items: $0) ] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        collectionView.rx.itemSelected.asDriver()
            .drive(onNext: { indexPath in
                guard let uri = dataSource[indexPath].uri else { return }
                if let topViewController = UIApplication.topViewController() {
                    topViewController.openProjectViewController(uri: uri)
                }
            })
            .disposed(by: disposeBag)
    }
}
