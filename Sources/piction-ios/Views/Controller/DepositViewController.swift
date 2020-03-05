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

// MARK: - UIViewController
final class DepositViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var pxlLabel: UILabel!

    @IBOutlet weak var depositGuidePiction1Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizationKey.str_deposit_guide_1.localized())

            // paragraphStyle
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10 // 들여쓰기
            paragraphStyle.lineHeightMultiple = 1.5 // 라인 간격

            // 폰트 사이즈
            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_1.localized()))
            // paragraphStyle 적용
            attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_1.localized()))
            depositGuidePiction1Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var depositGuidePiction2Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizationKey.str_deposit_guide_2.localized())

            // paragraphStyle
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10 // 들여쓰기
            paragraphStyle.lineHeightMultiple = 1.5 // 라인 간격

            // 폰트 사이즈
            attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_2.localized()))
            // paragraphStyle 적용
            attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_2.localized()))
            depositGuidePiction2Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var depositGuide1Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizationKey.str_deposit_guide_3.localized())

            // paragraphStyle
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10 // 들여쓰기
            paragraphStyle.lineHeightMultiple = 1.5 // 라인 간격

            // 폰트 사이즈
            attributedStr.addAttribute(.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_3.localized()))
            // paragraphStyle 적용
            attributedStr.addAttribute(.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_3.localized()))
            depositGuide1Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var depositGuide2Label: UILabel! {
        didSet {
            let attributedStr = NSMutableAttributedString(string: LocalizationKey.str_deposit_guide_4_piction.localized())

            // paragraphStyle
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 10 // 들여쓰기
            paragraphStyle.lineHeightMultiple = 1.5 // 라인 간격

             // 폰트 사이즈
            attributedStr.addAttribute(.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_4_piction.localized()))
             // paragraphStyle 적용
            attributedStr.addAttribute(.paragraphStyle, value: paragraphStyle, range: attributedStr.mutableString.range(of: LocalizationKey.str_deposit_guide_4_piction.localized()))
            depositGuide2Label.attributedText = attributedStr
        }
    }
    @IBOutlet weak var copyAddressButton: UIButton!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension DepositViewController: ViewModelBindable {
    typealias ViewModel = DepositViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = DepositViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            copyBtnDidTap: copyAddressButton.rx.tap.asDriver() // 주소 복사 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // 유저 정보를 불러와서 설정
        output
            .userInfo
            .map { $0.loginId }
            .flatMap(Driver.from)
            .map { LocalizationKey.str_wallet_address.localized(with: $0) }
            .drive(idLabel.rx.text)
            .disposed(by: disposeBag)

        // wallet 정보를 불러와서 설정
        output
            .walletInfo
            .drive(onNext: { [weak self] walletInfo in
                self?.addressLabel.text = "\(walletInfo.publicKey ?? "")"
                self?.pxlLabel.text = "\(walletInfo.amount.commaRepresentation) PXL"
                self?.stackView.isHidden = false
            })
            .disposed(by: disposeBag)

        // 주소 복사
        output
            .copyAddress
            .drive(onNext: { address in
                UIPasteboard.general.string = "\(address)"
                Toast.showToast(LocalizationKey.str_copy_address_complete.localized())
            })
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}
