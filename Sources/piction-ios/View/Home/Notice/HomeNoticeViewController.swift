//
//  HomeNoticeViewController.swift
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
import SafariServices
import PictionSDK

final class HomeNoticeViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    weak var delegate: HomeSectionDelegate?

    private func resizingCollectionViewFlowLayout() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let viewWidth = view.frame.size.width
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
            titleView.isHidden = collectionView.contentSize.height == 0
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.resizingCollectionViewFlowLayout()
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, BannerModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, BannerModel>>(
            configureCell: { (_, collectionView, indexPath, model) in
                let cell: HomeNoticeCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension HomeNoticeViewController: ViewModelBindable {

    typealias ViewModel = HomeNoticeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.dataSource = nil
        collectionView.delegate = nil

        let input = HomeNoticeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: collectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .noticeList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .noticeList
            .drive(onNext: { [weak self] _ in
                self?.resizingCollectionViewFlowLayout()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
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

        output
            .showErrorPopup
            .drive(onNext: { [weak self] _ in
                self?.delegate?.showErrorPopup()
            })
            .disposed(by: disposeBag)
    }
}
