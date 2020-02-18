//
//  PurchaseSponsorshipPlanViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class PurchaseSponsorshipPlanViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var sponsorshipPlanTitleLabel: UILabel!
    @IBOutlet weak var sponsorshipPlanDescriptionLabel: UILabel!
    @IBOutlet weak var descriptionButton: UIButton!
    @IBOutlet weak var descriptionButtonLabel: UILabel!
    @IBOutlet weak var descriptionStackView: UIView!
    @IBOutlet weak var pxlLabel: UILabel!
    @IBOutlet weak var paymentPxlLabel: UILabel!
    @IBOutlet weak var expireDateLabel: UILabel! {
        didSet  {
            if let expireDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) {
                expireDateLabel.text = expireDate.toString(format: LocalizationKey.str_sponsorship_plan_expire_description.localized())
            }
        }
    }
    @IBOutlet weak var transferInfoWriterLabel: UILabel!
    @IBOutlet weak var transferInfoWriterPxlLabel: UILabel!
    @IBOutlet weak var transferInfoFeeLabel: UILabel!
    @IBOutlet weak var transferInfoDescriptionLabel: UILabel!
    @IBOutlet weak var checkboxImageView: UIImageView!
    @IBOutlet weak var agreeButton: UIButton!
    @IBOutlet weak var purchaseButton: UIButton!

    private let authSuccessWithPincode = PublishSubject<Void>()
}

extension PurchaseSponsorshipPlanViewController: ViewModelBindable {
    typealias ViewModel = PurchaseSponsorshipPlanViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = PurchaseSponsorshipPlanViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            descriptionBtnDidTap: descriptionButton.rx.tap.asDriver(),
            agreeBtnDidTap: agreeButton.rx.tap.asDriver(),
            purchaseBtnDidTap: purchaseButton.rx.tap.asDriver().throttle(0.5),
            authSuccessWithPincode: authSuccessWithPincode.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .walletInfo
            .drive(onNext: { [weak self] walletInfo in
                self?.pxlLabel.text = "\(walletInfo.amount.commaRepresentation) PXL"
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                self?.transferInfoWriterLabel.text = "▪︎ \(projectInfo.user?.username ?? "") : "

                self?.transferInfoDescriptionLabel.text = LocalizationKey.str_sponsorship_plan_purchase_guide.localized(with: projectInfo.user?.username ?? "")
            })
            .disposed(by: disposeBag)

        output
            .sponsorshipPlanInfo
            .drive(onNext: { [weak self] (sponsorshipPlanItem, fees) in
                let price = sponsorshipPlanItem.sponsorshipPrice ?? 0
                let cdFee = Double(price) * ((fees.contentsDistributorRate ?? 0) / 100)
                let userAdoptionPoolFee = Double(price) * ((fees.userAdoptionPoolRate ?? 0) / 100)
                let depositPoolFee = Double(price) * ((fees.depositPoolRate ?? 0) / 100)
                let ecosystemFundFee = Double(price) * ((fees.ecosystemFundRate ?? 0) / 100)
                let supportPoolFee = Double(price) * ((fees.supportPoolRate ?? 0) / 100)
                let translatorFee = Double(price) * ((fees.translatorRate ?? 0) / 100)
                let marketerFee = Double(price) * ((fees.marketerRate ?? 0) / 100)

                let totalFeePxl = cdFee + userAdoptionPoolFee + depositPoolFee + ecosystemFundFee + supportPoolFee + translatorFee + marketerFee
                let writerPxl = Double(price) - totalFeePxl

                self?.paymentPxlLabel.text = "\(price.commaRepresentation) PXL"
                self?.transferInfoWriterPxlLabel.text = "\(writerPxl.commaRepresentation) PXL"
                self?.transferInfoFeeLabel.text = "\(totalFeePxl.commaRepresentation) PXL"

                self?.sponsorshipPlanTitleLabel.text = "\(LocalizationKey.str_sponsorship_plan_current_tier.localized(with: sponsorshipPlanItem.level ?? 0)) - \(sponsorshipPlanItem.name ?? "")"
                self?.sponsorshipPlanDescriptionLabel.text = sponsorshipPlanItem.description
                self?.descriptionStackView.isHidden = sponsorshipPlanItem.description == ""
            })
            .disposed(by: disposeBag)

        output
            .descriptionBtnDidTap
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.sponsorshipPlanDescriptionLabel.isHidden = !self.sponsorshipPlanDescriptionLabel.isHidden

                let labelText = self.sponsorshipPlanDescriptionLabel.isHidden ? LocalizationKey.str_sponsorship_plan_show_description.localized() : LocalizationKey.str_sponsorship_plan_hide_description.localized()

                let attributedStr = NSMutableAttributedString(string: labelText)
                attributedStr.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attributedStr.mutableString.range(of: labelText))
                self.descriptionButtonLabel.attributedText = attributedStr
            })
            .disposed(by: disposeBag)

        output
            .agreeBtnDidTap
            .drive(onNext: { [weak self] _ in
                guard let isEnabled = self?.purchaseButton.isEnabled else {
                    return
                }
                if isEnabled {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOff")
                    self?.purchaseButton.backgroundColor = .pictionLightGray
                    self?.purchaseButton.setTitleColor(.pictionGray, for: .normal)
                } else {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOn")
                    self?.purchaseButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                    self?.purchaseButton.setTitleColor(.white, for: .normal)
                }
                self?.purchaseButton.isEnabled = !isEnabled
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] message in
                Toast.loadingActivity(false)
                let title = message == "" ? LocalizationKey.popup_title_network_error.localized() : nil
                let message = message == "" ? LocalizationKey.msg_api_internal_server_error.localized() : message

                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let okAction = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default, handler: { action in
                        self?.navigationController?.popViewController(animated: true)
                    })
                alert.addAction(okAction)

                self?.present(alert, animated: false, completion: nil)

            })
            .disposed(by: disposeBag)

        output
            .openCheckPincodeViewController
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.openCheckPincodeViewController(delegate: self)
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.dismiss(animated: true, completion: {
                    if message != "" {
                        Toast.loadingActivity(false)
                        Toast.showToast(message)
                    }
                })
            })
            .disposed(by: disposeBag)
    }
}

extension PurchaseSponsorshipPlanViewController: CheckPincodeDelegate {
    func authSuccess() {
        self.authSuccessWithPincode.onNext(())
    }
}
