//
//  HomeSubscriptionViewController.swift
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
import PictionSDK

final class HomeSubscriptionViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    weak var delegate: HomeSectionDelegate?

    private func resizingCollectionViewFlowLayout() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let width = 200
            let height = width + 111
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
//            heightConstraint.constant = collectionView.contentSize.height > 0 ? 311 : 0
            titleView.isHidden = collectionView.contentSize.width == 0
            collectionView.isHidden = collectionView.contentSize.width == 0
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.resizingCollectionViewFlowLayout()
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, HomeSubscriptionModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, HomeSubscriptionModel>>(
            configureCell: { (_, collectionView, indexPath, model) in
                let cell: HomeSubscriptionCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension HomeSubscriptionViewController: ViewModelBindable {

    typealias ViewModel = HomeSubscriptionViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.dataSource = nil
        collectionView.delegate = nil

        let input = HomeSubscriptionViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            moreBtnDidTap: moreButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .subscriptionList
            .drive { $0 }
            .map { [SectionModel(model: "subscriptions", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .subscriptionList
            .drive(onNext: { [weak self] _ in
                self?.resizingCollectionViewFlowLayout()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .openSubscriptionListViewController
            .drive(onNext: { _ in
                if let url = URL(string: "\(AppInfo.urlScheme)://my-subscription") {
                    UIApplication.dismissAllPresentedController {
                        _ = DeepLinkManager.executeDeepLink(with: url)
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
