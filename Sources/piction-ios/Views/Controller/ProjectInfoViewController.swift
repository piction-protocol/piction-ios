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

final class ProjectInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var synopsisLabel: UILabel!
    @IBOutlet weak var creatorInfoStackView: UIStackView!
    @IBOutlet weak var synopsisStackView: UIStackView!
    @IBOutlet weak var tagStackView: UIStackView!
    @IBOutlet weak var tagCollectionView: UICollectionView!

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, String>> {
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
        let dataSource = configureDataSource()

        tagCollectionView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ProjectInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tagCollectionView.rx.itemSelected.asDriver()
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
                self?.tagStackView.isHidden = projectInfo.tags?.count == 0
                self?.creatorInfoStackView.isHidden = projectInfo.user == nil
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "tags", items: $0.tags ?? [])] }
            .bind(to: tagCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                let tag = dataSource[indexPath]
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
                    action: LocalizationKey.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)
    }
}

extension ProjectInfoViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let cell = collectionView.dataSource?.collectionView(collectionView, cellForItemAt: indexPath) as? ProjectInfoTagCollectionViewCell {
            let text = cell.tagLabel.text ?? ""
            let cellWidth = text.size(withAttributes:[.font: UIFont.systemFont(ofSize: 14.0)]).width + 30.0
            return CGSize(width: cellWidth, height: 30.0)
        }
        return .zero
    }
}
