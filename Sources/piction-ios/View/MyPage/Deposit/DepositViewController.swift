//
//  DepositViewController.swift
//  PictionSDK
//
//  Created by jhseo on 13/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class DepositViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var pxlLabel: UILabel!

    @IBOutlet weak var depositGuidePiction1Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizedStrings.str_deposit_guide_1.localized())

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10
            paragraphStyle.lineHeightMultiple = 1.5

            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_1.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_1.localized()))
            depositGuidePiction1Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var depositGuidePiction2Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizedStrings.str_deposit_guide_2.localized())

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10
            paragraphStyle.lineHeightMultiple = 1.5

            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_2.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_2.localized()))
            depositGuidePiction2Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var depositGuide1Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizedStrings.str_deposit_guide_3.localized())

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10
            paragraphStyle.lineHeightMultiple = 1.5

            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_3.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_3.localized()))
            depositGuide1Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var depositGuide2Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizedStrings.str_deposit_guide_4_piction.localized())

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10
            paragraphStyle.lineHeightMultiple = 1.5

            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_4_piction.localized()))
            attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizedStrings.str_deposit_guide_4_piction.localized()))
            depositGuide2Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var copyAddressButton: UIButton!
}

extension DepositViewController: ViewModelBindable {
    typealias ViewModel = DepositViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = DepositViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            copyBtnDidTap: copyAddressButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                self?.idLabel.text = LocalizedStrings.str_wallet_address.localized(with: userInfo.loginId ?? "")
            })
            .disposed(by: disposeBag)

        output
            .walletInfo
            .drive(onNext: { [weak self] walletInfo in
                self?.addressLabel.text = "\(walletInfo.publicKey ?? "")"
                self?.pxlLabel.text = "\(walletInfo.amount.commaRepresentation) PXL"
            })
            .disposed(by: disposeBag)

        output
            .copyAddress
            .drive(onNext: { address in
                UIPasteboard.general.string = "\(address)"
                Toast.showToast(LocalizedStrings.str_copy_address_complete.localized())
            })
            .disposed(by: disposeBag)
    }
}
