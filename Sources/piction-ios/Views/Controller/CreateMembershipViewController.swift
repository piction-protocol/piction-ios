//
//  CreateMembershipViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

// MARK: - UIViewController
final class CreateMembershipViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var limitButton: UIButton!
    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var checkboxImageView: UIImageView!
    @IBOutlet weak var limitStackView: UIStackView!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CreateMembershipViewController: ViewModelBindable {
    typealias ViewModel = CreateMembershipViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = CreateMembershipViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            membershipName: nameTextField.rx.text.orEmpty.asDriver(),
            membershipPrice: priceTextField.rx.text.asDriver(),
            membershipDescription: descriptionTextField.rx.text.asDriver(),
            membershipLimit: limitTextField.rx.text.asDriver(),
            limitBtnDidTap: limitButton.rx.tap.asDriver(),
            saveBtnDidTap: saveButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { $0.level ?? 0 == 0 ? .pictionGray : .pictionDarkGrayDM }
            .drive(onNext: { [weak self] in
                self?.priceTextField.textColor = $0
            })
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { $0.name ?? "" }
            .drive(nameTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { String($0.price ?? 0) }
            .drive(priceTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { $0.description }
            .filter { $0 != nil }
            .drive(descriptionTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { String($0.sponsorLimit ?? 0) }
            .drive(limitTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { $0.sponsorLimit == nil }
            .drive(limitTextField.rx.isHidden)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { $0.sponsorLimit == nil ? #imageLiteral(resourceName: "checkboxOn") : #imageLiteral(resourceName: "checkboxOff") }
            .drive(checkboxImageView.rx.image)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { ($0.level ?? 0) == 0 }
            .drive(limitStackView.rx.isHidden)
            .disposed(by: disposeBag)

        output
            .loadMembership
            .map { ($0.level ?? 0) > 0 }
            .drive(priceTextField.rx.isEnabled)
            .disposed(by: disposeBag)

        output
            .limitBtnDidTap
            .drive(onNext: { [weak self] _ in
                self?.view.endEditing(true)
                guard let isEnabled = self?.limitTextField.isHidden else { return }
                self?.checkboxImageView.image = isEnabled ? #imageLiteral(resourceName: "checkboxOff") : #imageLiteral(resourceName: "checkboxOn")
                self?.limitTextField.isHidden = !isEnabled
                self?.limitTextField.text = "0"
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .popViewController
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.navigationController?.popViewController(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .dismissKeyboard
            .drive(onNext: { [weak self] _ in
                self?.view.endEditing(true)
            })
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}
