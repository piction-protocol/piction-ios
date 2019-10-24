//
//  HomeSubscriptionSectionTableViewCell.swift
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

struct SubscriptionSectionModel {
    let project: ProjectModel
    let post: PostModel
}

final class HomeSubscriptionSectionTableViewCell: ReuseTableViewCell {
    var disposeBag = DisposeBag()

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    typealias Model = ([ProjectModel], [PostModel])

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let width = 200
            let height = width + 111
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

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, SubscriptionSectionModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, SubscriptionSectionModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: SubscriptionSectionCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }

    func configure(projects: [ProjectModel], posts: [PostModel]) {
        collectionView.dataSource = nil
        collectionView.delegate = nil

        var sectionModel: [SubscriptionSectionModel] = []
        for (index, element) in projects.enumerated() {
            sectionModel.append(SubscriptionSectionModel(project: element, post: posts[index]))
        }

        let dataSource = configureDataSource()
        Observable.just(sectionModel)
            .map { [SectionModel(model: "subscriptions", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
}
