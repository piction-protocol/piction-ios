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

// MARK: - CreatorHeaderViewDelegate
protocol CreatorHeaderViewDelegate: class {
    func loadComplete()
    func setNavigationTitle(title: String)
}

// MARK: - UIViewController
final class CreatorProfileHeaderViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var profileImageView: UIImageViewExtension!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var linkCollectionView: UICollectionView!
    @IBOutlet weak var greetingStackView: UIStackView!
    @IBOutlet weak var greetingTextView: UITextView! {
        didSet {
            // 기본으로 적용되어 있는 TextView의 패딩과 라인간격을 없앰
            greetingTextView.textContainerInset = .zero
            greetingTextView.textContainer.lineFragmentPadding = 0
        }
    }

    weak var delegate: CreatorHeaderViewDelegate?

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CreatorProfileHeaderViewController: ViewModelBindable {
    typealias ViewModel = CreatorProfileHeaderViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CreatorProfileHeaderViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            selectedIndexPath: linkCollectionView.rx.itemSelected.asDriver() // collectionView의 item을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // creatorProfile 정보를 받아와서 각 항목에 설정
        output
            .creatorProfile
            .drive(onNext: { [weak self] creatorProfile in
                self?.greetingTextView.text = creatorProfile.greetings
                self?.greetingStackView.isHidden = creatorProfile.greetings?.isEmpty ?? true
                self?.linkCollectionView.isHidden = creatorProfile.links?.isEmpty ?? true
            })
            .disposed(by: disposeBag)

        // Creator 정보를 가져와서 각 항목에 설정
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

        // Creator 정보의 Link 목록을 가져와서 collectionView에 출력
        output
            .creatorLinkList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: linkCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // collectionView에 출력되면 loadComplete delegate를 호출
        output
            .creatorLinkList
            .drive(onNext: { [weak self] _ in
                self?.linkCollectionView.layoutIfNeeded()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        // Creator 정보의 Link를 누르면 SafariView에서 해당 링크로 이동
        output
            .selectedIndexPath
            .map { dataSource[$0].url }
            .filter { $0 != nil }
            .flatMap(Driver.from)
            .drive(onNext: { [weak self] in
                self?.openSafariViewController(url: $0)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension CreatorProfileHeaderViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CreatorLinkModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CreatorLinkModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: CreatorProfileLinkCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            })
    }
}
