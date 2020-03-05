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

// MARK: - UIViewController
final class SignUpCompleteViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 뒤로가기 버튼을 숨기고 죄측 스와이프해서 뒤로가는 기능도 비활성화
        self.navigationItem.hidesBackButton = true
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SignUpCompleteViewController: ViewModelBindable {
    typealias ViewModel = SignUpCompleteViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = SignUpCompleteViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            closeBtnDidTap: closeButton.rx.tap.asDriver() // 확인 버튼을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // 확인 버튼 눌렀을 때 화면을 닫고 pincode 등록되지 않았으면 pincode 등록 화면 출력
        output
            .dismissViewController
            .drive(onNext: { [weak self] pincode in
                self?.dismiss(animated: true) {
                    if pincode.isEmpty {
                        self?.openView(type: .registerPincode, openType: .present)
                    }
                }
            })
            .disposed(by: disposeBag)
    }
}
