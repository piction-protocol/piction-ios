//
//  PurchaseMembershipViewController.swift
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

// MARK: - UIViewController
final class PurchaseMembershipViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var membershipTitleLabel: UILabel!
    @IBOutlet weak var membershipDescriptionLabel: UILabel!
    @IBOutlet weak var descriptionButton: UIButton!
    @IBOutlet weak var descriptionButtonLabel: UILabel!
    @IBOutlet weak var descriptionStackView: UIView!
    @IBOutlet weak var pxlLabel: UILabel!
    @IBOutlet weak var paymentPxlLabel: UILabel!
    @IBOutlet weak var expireDateLabel: UILabel! {
        didSet  {
            // 현재 날짜에서 30일을 더해서 보여줌
            if let expireDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) {
                expireDateLabel.text = expireDate.toString(format: LocalizationKey.str_membership_expire_description.localized())
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

    // pincode가 설정되어 있고 인증되었을 때 Observable
    private let authSuccessWithPincode = PublishSubject<Void>()

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension PurchaseMembershipViewController: ViewModelBindable {
    typealias ViewModel = PurchaseMembershipViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = PurchaseMembershipViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            descriptionBtnDidTap: descriptionButton.rx.tap.asDriver(), // 설명 보기/닫기 버튼 누를 때
            agreeBtnDidTap: agreeButton.rx.tap.asDriver(), // 동의 버튼 누를 때
            purchaseBtnDidTap: purchaseButton.rx.tap.asDriver().throttle(0.5), // 구매 버튼 누를 때
            authSuccessWithPincode: authSuccessWithPincode.asDriver(onErrorDriveWith: .empty()) // Pincode가 정상적으로 입력되었을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // Wallet 정보를 받아오면 pxlLabel에 출력
        output
            .walletInfo
            .map { "\($0.amount.commaRepresentation) PXL" }
            .drive(pxlLabel.rx.text)
            .disposed(by: disposeBag)

        // 프로젝트 정보를 받아와서 하단 송금안내에 크리에이터 이름 출력
        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                self?.transferInfoWriterLabel.text = "▪︎ \(projectInfo.user?.username ?? "")"

                self?.transferInfoDescriptionLabel.text = LocalizationKey.str_membership_purchase_guide.localized(with: projectInfo.user?.username ?? "")
            })
            .disposed(by: disposeBag)

        // 멤버쉽 정보를 받아와서 후원플랜 제목/설명, 수수료 계산, 결제 금액 출력
        output
            .membershipInfo
            .drive(onNext: { [weak self] (membershipItem, fees) in
                let price = membershipItem.price ?? 0
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

                self?.membershipTitleLabel.text = "\(LocalizationKey.str_membership_current_tier.localized(with: membershipItem.level ?? 0)) - \(membershipItem.name ?? "")"
                self?.membershipDescriptionLabel.text = membershipItem.description
                self?.descriptionStackView.isHidden = membershipItem.description == ""
            })
            .disposed(by: disposeBag)

        // 설명 보기 버튼 눌렀을때 설명 보기/숨기기 설정
        output
            .descriptionBtnDidTap
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.membershipDescriptionLabel.isHidden = !self.membershipDescriptionLabel.isHidden

                let labelText = self.membershipDescriptionLabel.isHidden ? LocalizationKey.str_membership_show_description.localized() : LocalizationKey.str_membership_hide_description.localized()

                let attributedStr = NSMutableAttributedString(string: labelText)
                attributedStr.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attributedStr.mutableString.range(of: labelText))
                self.descriptionButtonLabel.attributedText = attributedStr
            })
            .disposed(by: disposeBag)

        // 하단 동의버튼 눌렀을때 결제 버튼 활성/비활성화 설정
        output
            .agreeBtnDidTap
            .drive(onNext: { [weak self] in
                guard let isEnabled = self?.purchaseButton.isEnabled else {
                    return
                }
                if isEnabled {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOff")
                    self?.purchaseButton.backgroundColor = .pictionLightGray
                    self?.purchaseButton.setTitleColor(.pictionGray, for: .normal)
                } else {
                    self?.checkboxImageView.image = #imageLiteral(resourceName: "checkboxOn")
                    self?.purchaseButton.backgroundColor = .pictionDarkGray
                    self?.purchaseButton.setTitleColor(.white, for: .normal)
                }
                self?.purchaseButton.isEnabled = !isEnabled
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 에러 발생 시 팝업 출력
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

        // 결제 시 Pincode가 있다면 Pincode 입력 화면 출력
        output
            .openCheckPincodeViewController
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.openView(type: .checkPincode(delegate: self), openType: .present)
            })
            .disposed(by: disposeBag)

        // 결제 완료 시 화면 닫기
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

// MARK: - CheckPincodeDelegate
extension PurchaseMembershipViewController: CheckPincodeDelegate {
    // Pincode check 완료 delegate
    func authSuccess() {
        self.authSuccessWithPincode.onNext(())
    }
}
