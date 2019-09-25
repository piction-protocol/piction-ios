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
                self?.navigationController?.navigationBar.prefersLargeTitles = false
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                self?.idLabel.text = "@\(userInfo.loginId ?? "")의 지갑주소"
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
                Toast.showToast("지갑 주소가 복사되었습니다.")
            })
            .disposed(by: disposeBag)
    }
}
