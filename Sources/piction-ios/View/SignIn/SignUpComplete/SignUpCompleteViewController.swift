//
//  SignUpCompleteViewController.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class SignUpCompleteViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.hidesBackButton = true
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
}

extension SignUpCompleteViewController: ViewModelBindable {

    typealias ViewModel = SignUpCompleteViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = SignUpCompleteViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                let loginId = self?.viewModel?.loginId ?? ""
                FirebaseManager.screenName("회원가입완료_\(loginId)")
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true, completion: { [weak self] in
                    if KeychainManager.get(key: "pincode").isEmpty {
                        self?.openRegisterPincodeViewController()
                    }
                })
            })
            .disposed(by: disposeBag)
    }
}
