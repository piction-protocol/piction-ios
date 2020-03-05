//
//  PostHeaderViewController.swift
//  PictionView
//
//  Created by jhseo on 11/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

// MARK: - UIViewController
final class PostHeaderViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var seriesNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var creatorButton: UIButton!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension PostHeaderViewController: ViewModelBindable {
    typealias ViewModel = PostHeaderViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = PostHeaderViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            creatorBtnDidTap: creatorButton.rx.tap.asDriver() // creator 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 헤더 정보 불러와서 설정
        output
            .headerInfo
            .drive(onNext: { [weak self] (postItem, userInfo) in
                if let profileImage = userInfo.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
                    if let url = URL(string: userPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                }
                self?.seriesNameLabel.isHidden = postItem.series?.name == nil
                self?.seriesNameLabel.text = postItem.series?.name ?? ""
                self?.writerLabel.text = userInfo.username
                self?.titleLabel.text = postItem.title
            })
            .disposed(by: disposeBag)

        // creator profile 버튼 누르면 creator profile 화면으로 push
        output
            .openCreatorProfileViewController
            .map { .creatorProfile(loginId: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)
    }
}
