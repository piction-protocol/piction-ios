//
//  HomeTrendingViewController.swift
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

final class HomeTrendingViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    weak var delegate: HomeSectionDelegate?

    private func resizingCollectionViewFlowLayout() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let viewWidth = view.frame.size.width
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && viewWidth == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (viewWidth - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
            heightConstraint.constant = collectionView.contentSize.height
            titleView.isHidden = collectionView.contentSize.height == 0
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.resizingCollectionViewFlowLayout()
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { (_, collectionView, indexPath, model) in
                let cell: HomeTrendingCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension HomeTrendingViewController: ViewModelBindable {

    typealias ViewModel = HomeTrendingViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.dataSource = nil
        collectionView.delegate = nil

        let input = HomeTrendingViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: collectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .trendingList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .trendingList
            .drive(onNext: { [weak self] _ in
                self?.resizingCollectionViewFlowLayout()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                if let item: ProjectModel = try? self?.collectionView.rx.model(at: indexPath) {
                    self?.openProjectViewController(uri: item.uri ?? "")
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
