//
//  CreatorProfileHeaderViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/19.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

protocol CreatorHeaderViewDelegate: class {
    func loadComplete()
    func setNavigationTitle(title: String)
}

final class CreatorProfileHeaderViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var profileImageView: UIImageViewExtension!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var linkCollectionView: UICollectionView!
    @IBOutlet weak var greetingStackView: UIStackView!
    @IBOutlet weak var greetingTextView: UITextView! {
        didSet {
            greetingTextView.textContainerInset = .zero
            greetingTextView.textContainer.lineFragmentPadding = 0
        }
    }

    weak var delegate: CreatorHeaderViewDelegate?

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CreatorLinkModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CreatorLinkModel>>(

            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: CreatorProfileLinkCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            })
    }
}

extension CreatorProfileHeaderViewController: ViewModelBindable {
    typealias ViewModel = CreatorProfileHeaderViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CreatorProfileHeaderViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: linkCollectionView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .creatorProfile
            .drive(onNext: { [weak self] creatorProfile in
                self?.greetingTextView.text = creatorProfile.greetings
                self?.greetingStackView.isHidden = creatorProfile.greetings?.isEmpty ?? true
                self?.linkCollectionView.isHidden = creatorProfile.links?.isEmpty ?? true
            })
            .disposed(by: disposeBag)

        output
            .creatorInfo
            .drive(onNext: { [weak self] creatorInfo in
                if let profileImage = creatorInfo.picture {
                    let creatorPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"

                    if let url = URL(string: creatorPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                }
                self?.loginIdLabel.text = "@\(creatorInfo.loginId ?? "")"
                self?.usernameLabel.text = creatorInfo.username
                self?.delegate?.setNavigationTitle(title: creatorInfo.username ?? "")
            })
            .disposed(by: disposeBag)

        output
            .creatorLinkList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: linkCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .creatorLinkList
            .drive(onNext: { [weak self] _ in
                self?.linkCollectionView.layoutIfNeeded()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .map { dataSource[$0].url }
            .filter { $0 != nil }
            .flatMap(Driver.from)
            .drive(onNext: { self.openSafariViewController(url: $0) })
            .disposed(by: disposeBag)
    }
}
