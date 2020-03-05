//
//  UserInfoViewController.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

// MARK: - UIViewController
final class UserInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var profileImageButton: UIButton!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension UserInfoViewController: ViewModelBindable {
    typealias ViewModel = UserInfoViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = UserInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver() // 화면이 보여지기 전에
        )

        let output = viewModel.build(input: input)

        // user 정보를 불러와서 프로필 이미지, 닉네임, 로그인ID를 설정
        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                if let profileImage = userInfo.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"

                    if let url = URL(string: userPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                }
                self?.userNameLabel.text = userInfo.username
                self?.loginIdLabel.text = "@\(userInfo.loginId ?? "")"
            })
            .disposed(by: disposeBag)

        // wallet 정보를 불러와서 amount 설정
        output
            .walletInfo
            .map { "\($0.amount.commaRepresentation) PXL" }
            .drive(amountLabel.rx.text)
            .disposed(by: disposeBag)
    }
}
