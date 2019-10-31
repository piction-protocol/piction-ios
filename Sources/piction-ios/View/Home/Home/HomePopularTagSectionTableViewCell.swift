//
//  HomePopularTagSectionTableViewCell.swift
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

struct PopularTagSectionModel {
    let tag: TagModel
    let thumbnail: String?
}

final class HomePopularTagSectionTableViewCell: ReuseTableViewCell {
    var disposeBag = DisposeBag()

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    typealias Model = ([TagModel], [String])

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
            let height = width / 1.6
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()

            heightConstraint.constant = collectionView.contentSize.height
        }
    }

    private func openTagResultProjectViewController(tag: String) {
        let vc = TagResultProjectViewController.make(tag: tag)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, PopularTagSectionModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, PopularTagSectionModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: PopularTagSectionCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }

    func configure(tags: [TagModel], thumbnails: [String]) {
        collectionView.dataSource = nil
        collectionView.delegate = nil

        var sectionModel: [PopularTagSectionModel] = []
        for (index, element) in tags.enumerated() {
            sectionModel.append(PopularTagSectionModel(tag: element, thumbnail: thumbnails[safe: index] ?? ""))
        }

        let dataSource = configureDataSource()

        Observable.just(sectionModel)
            .map { [SectionModel(model: "tags", items: $0) ] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        collectionView.rx.itemSelected.asDriver()
            .drive(onNext: { [weak self] indexPath in
                if let item: PopularTagSectionModel = try? self?.collectionView.rx.model(at: indexPath) {
                    self?.openTagResultProjectViewController(tag: item.tag.name ?? "")
                }
            })
            .disposed(by: disposeBag)
    }
}
