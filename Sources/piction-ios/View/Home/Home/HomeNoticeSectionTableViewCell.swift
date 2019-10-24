//
//  HomeNoticeSectionTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import SafariServices
import PictionSDK

final class HomeNoticeSectionTableViewCell: ReuseTableViewCell {
    var disposeBag = DisposeBag()

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    typealias Model = [BannerModel]

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let viewWidth = UIApplication.topViewController()?.view.frame.size.width ?? 0
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && viewWidth == UIScreen.main.bounds.size.width ? 2 : 1
            let lineSpacing: CGFloat = cellCount == 2 ? 20 : 0
            let itemSpacing: CGFloat = cellCount == 2 ? 7 : 0
            let sectionInset: CGFloat = cellCount == 2 ? 20 : 0

            let width = (viewWidth - (sectionInset * 2) - (cellCount - 1) * lineSpacing) / cellCount
            let height = width / 2
            flowLayout.sectionInset = cellCount == 2 ? UIEdgeInsets(top: 0, left: sectionInset, bottom: sectionInset, right: sectionInset) : UIEdgeInsets.zero
            flowLayout.minimumLineSpacing = lineSpacing
            flowLayout.minimumInteritemSpacing = itemSpacing
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()

            heightConstraint.constant = collectionView.contentSize.height
        }
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, BannerModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, BannerModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: NoticeSectionCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }

    func configure(with model: Model) {
        collectionView.dataSource = nil
        collectionView.delegate = nil

        let dataSource = configureDataSource()
        Observable.just(model)
            .map { [SectionModel(model: "banners", items: $0) ] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        collectionView.rx.itemSelected.asDriver()
            .drive(onNext: { [weak self] indexPath in
                if let item: BannerModel = try? self?.collectionView.rx.model(at: indexPath) {
                    guard let url = URL(string: item.link ?? "") else { return }
                    let safariViewController = SFSafariViewController(url: url)
                    if let topViewController = UIApplication.topViewController() {
                        topViewController.present(safariViewController, animated: true, completion: nil)
                    }
                }
            })
            .disposed(by: disposeBag)
    }
}
