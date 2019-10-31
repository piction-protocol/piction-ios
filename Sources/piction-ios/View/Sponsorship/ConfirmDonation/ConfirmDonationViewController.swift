//
//  ConfirmDonationViewController.swift
//  PictionSDK
//
//  Created by jhseo on 20/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import PictionSDK

final class ConfirmDonationViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var profileWideImageView: UIImageView!
    @IBOutlet weak var profileVisualEffectView: VisualEffectView! {
        didSet {
            profileVisualEffectView.blurRadius = 5
        }
    }
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var descriptionLabel: UILabel! {
        didSet {
            descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        }
    }
}

extension ConfirmDonationViewController: ViewModelBindable {
    typealias ViewModel = ConfirmDonationViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = ConfirmDonationViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            confirmBtnDidTap: confirmButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.tabBarController?.tabBar.isHidden = true
                self?.navigationItem.hidesBackButton = true
                self?.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationItem.hidesBackButton = false
                self?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
                self?.tabBarController?.tabBar.isHidden = false
            })
            .disposed(by: disposeBag)

        output
            .sendAmountInfo
            .drive(onNext: { [weak self] sendAmount in
                self?.amountLabel.text = "\(sendAmount.commaRepresentation) PXL"
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                if let profileImage = userInfo.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
                    if let url = URL(string: userPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"))
                        self?.profileWideImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"))
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                    self?.profileWideImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                }
                let loginId = LocalizedStrings.str_id_with_at.localized(with: userInfo.loginId ?? "")
                let attributedStr = NSMutableAttributedString(string: LocalizedStrings.str_creator_sponsorship.localized(with: userInfo.loginId ?? ""))
                attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 18), range: attributedStr.mutableString.range(of: loginId))

                self?.loginIdLabel.attributedText = attributedStr
            })
            .disposed(by: disposeBag)

        output
            .popViewController
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
                self?.navigationItem.hidesBackButton = false
                self?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
                self?.tabBarController?.tabBar.isHidden = false

                guard let viewControllers = self?.navigationController?.viewControllers else { return }

                if let vc = viewControllers.filter( {$0 is ProjectInfoViewController} ).first {
                    self?.navigationController?.popToViewController(vc, animated: true)
                }
                if let _ = viewControllers.filter( {$0 is SearchSponsorViewController} ).first {
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            })
            .disposed(by: disposeBag)
    }
}
