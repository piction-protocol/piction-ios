//
//  CreatorProfileViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/18.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class CreatorProfileViewController: UIViewController {
    var disposeBag = DisposeBag()

    var creatorProfileHeaderView: CreatorProfileHeaderViewController?

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.registerXib(ProjectListCollectionViewCell.self)
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .header)
        }
    }

    private func embedCreatorProfileHeaderViewController(loginId: String) {
        creatorProfileHeaderView = CreatorProfileHeaderViewController.make(loginId: loginId)
        creatorProfileHeaderView?.delegate = self
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(

            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }

                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .header)

                    if reusableView.subviews.isEmpty {
                        if let creatorProfileHeaderView = self.creatorProfileHeaderView {
                            self.embed(creatorProfileHeaderView, to: reusableView)
                        }
                    }
                    reusableView.layoutIfNeeded()
                    return reusableView
                default:
                    return UICollectionReusableView()
                }
            })
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }
}

extension CreatorProfileViewController: ViewModelBindable {
    typealias ViewModel = CreatorProfileViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CreatorProfileViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: collectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .embedCreatorProfileHeaderViewController
            .drive(onNext: { self.embedCreatorProfileHeaderViewController(loginId: $0) })
            .disposed(by: disposeBag)

        output
            .creatorProjectList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .creatorProjectList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .map { dataSource[$0].uri }
            .filter { $0 != nil }
            .flatMap(Driver.from)
            .drive(onNext: { self.openProjectViewController(uri: $0) })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.showPopup(
                title: nil,
                message: message,
                action: [LocalizationKey.confirm.localized()]) { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            })
            .disposed(by: disposeBag)
    }
}

extension CreatorProfileViewController: CreatorHeaderViewDelegate {
    func loadComplete() {
        collectionView.reloadData()
    }

    func setNavigationTitle(title: String) {
        self.navigationItem.title = title
    }
}

extension CreatorProfileViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let defaultHeight: CGFloat = 259

        if let headerView = creatorProfileHeaderView {
            let height = headerView.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            let linkCollectionViewHeight = headerView.linkCollectionView.contentSize.height
            let greetingHeight = headerView.greetingTextView.sizeThatFits(CGSize(width: headerView.view.frame.size.width, height: CGFloat.greatestFiniteMagnitude)).height
            return CGSize(width: view.frame.size.width, height: height + greetingHeight + linkCollectionViewHeight)
        }
        return CGSize(width: view.frame.size.width, height: defaultHeight)
     }
}
