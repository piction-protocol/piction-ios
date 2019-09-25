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

final class UserInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var profileImageButton: UIButton!
}

extension UserInfoViewController: ViewModelBindable {

    typealias ViewModel = UserInfoViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = UserInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                let userPictureWithIC = "\(userInfo.picture ?? "")?w=240&h=240&quality=80&output=webp"

                if let url = URL(string: userPictureWithIC) {
                    self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                }
                self?.userNameLabel.text = userInfo.username
                self?.loginIdLabel.text = "@\(userInfo.loginId ?? "")"
            })
            .disposed(by: disposeBag)

        output
            .walletInfo
            .drive(onNext: { [weak self] walletInfo in
                self?.amountLabel.text = "\(walletInfo.amount.commaRepresentation) PXL"
            })
            .disposed(by: disposeBag)
    }
}
