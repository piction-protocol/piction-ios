//
//  ProjectInfoViewController.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class ProjectInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var synopsisLabel: UILabel!
    @IBOutlet weak var creatorInfoStackView: UIStackView!
    @IBOutlet weak var synopsisStackView: UIStackView!
    @IBOutlet weak var categoryStackView: UIStackView!
    @IBOutlet weak var tagStackView: UIStackView!
    @IBOutlet weak var categoryCollectionView: UICollectionView!
    @IBOutlet weak var tagCollectionView: UICollectionView!

    private func categoryConfigureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectInfoCategoryCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }

    private func tagConfigureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, String>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, String>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectInfoTagCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension ProjectInfoViewController: ViewModelBindable {
    typealias ViewModel = ProjectInfoViewModel

    func bindViewModel(viewModel: ViewModel) {
        let categoryDataSource = categoryConfigureDataSource()
        let tagDataSource = tagConfigureDataSource()

        categoryCollectionView.rx.setDelegate(self)
            .disposed(by: disposeBag)
        tagCollectionView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ProjectInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            categoryCollectionViewSelectedIndexPath: categoryCollectionView.rx.itemSelected.asDriver(),
            tagCollectionViewSelectedIndexPath: tagCollectionView.rx.itemSelected.asDriver(),
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                if let profileImage = projectInfo.user?.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
                    if let url = URL(string: userPictureWithIC) {
                        self?.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                    }
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                }
                self?.writerLabel.text = projectInfo.user?.username
                self?.loginIdLabel.text = "@\(projectInfo.user?.loginId ?? "")"
                self?.synopsisStackView.isHidden = projectInfo.synopsis == ""
                self?.synopsisLabel.text = projectInfo.synopsis ?? ""
                self?.categoryStackView.isHidden = projectInfo.categories?.isEmpty ?? true
                self?.tagStackView.isHidden = projectInfo.tags?.isEmpty ?? true
                self?.creatorInfoStackView.isHidden = projectInfo.user == nil
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "tag", items: $0.tags ?? [])] }
            .bind(to: tagCollectionView.rx.items(dataSource: tagDataSource))
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "category", items: $0.categories ?? [])] }
            .bind(to: categoryCollectionView.rx.items(dataSource: categoryDataSource))
            .disposed(by: disposeBag)

        output
            .categoryCollectionViewSelectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let categoryId = categoryDataSource[indexPath].id else { return }
                self?.openCategorizedProjectViewController(id: categoryId)
            })
            .disposed(by: disposeBag)

        output
            .tagCollectionViewSelectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                let tag = tagDataSource[indexPath]
                self?.openTaggingProjectViewController(tag: tag)
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}

extension ProjectInfoViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let cell = collectionView.dataSource?.collectionView(collectionView, cellForItemAt: indexPath) as? ProjectInfoCategoryCollectionViewCell {
            let text = cell.categoryLabel.text ?? ""
            let cellWidth = text.size(withAttributes:[.font: UIFont.systemFont(ofSize: 14.0)]).width + 60.0
            return CGSize(width: cellWidth, height: 36.0)
        } else if let cell = collectionView.dataSource?.collectionView(collectionView, cellForItemAt: indexPath) as? ProjectInfoTagCollectionViewCell {
            let text = cell.tagLabel.text ?? ""
            let cellWidth = text.size(withAttributes:[.font: UIFont.systemFont(ofSize: 14.0)]).width + 30.0
            return CGSize(width: cellWidth, height: 30.0)
        }
        return .zero
    }
}
