//
//  HomeTrendingSectionTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import PictionSDK

final class HomeTrendingSectionTableViewCell: ReuseTableViewCell {
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
            collectionView.layoutIfNeeded()

            heightConstraint.constant = collectionView.contentSize.height
        }
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: TrendingSectionCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
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
            .drive(onNext: { [weak self] indexPath in
                if let item: ProjectModel = try? self?.collectionView.rx.model(at: indexPath) {
                    self?.openProjectViewController(uri: item.uri ?? "")
                }
            })
            .disposed(by: disposeBag)
    }
}
