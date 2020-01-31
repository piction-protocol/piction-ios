//
//  CreateFanPassViewController.swift
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

final class CreateFanPassViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var limitButton: UIButton!
    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var checkboxImageView: UIImageView!
    @IBOutlet weak var limitStackView: UIStackView!
}

extension CreateFanPassViewController: ViewModelBindable {
    typealias ViewModel = CreateFanPassViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = CreateFanPassViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            fanPassName: nameTextField.rx.text.orEmpty.asDriver(),
            fanPassPrice: priceTextField.rx.text.asDriver(),
            fanPassDescription: descriptionTextField.rx.text.asDriver(),
            fanPassLimit: limitTextField.rx.text.asDriver(),
            limitBtnDidTap: limitButton.rx.tap.asDriver(),
            saveBtnDidTap: saveButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { $0.level ?? 0 == 0 ? .pictionGray : .pictionDarkGrayDM }
            .drive(onNext: { [weak self] textColor in
                self?.priceTextField.textColor = textColor
            })
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { $0.name ?? "" }
            .drive(nameTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { String($0.subscriptionPrice ?? 0) }
            .drive(priceTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { $0.description }
            .filter { $0 != nil }
            .drive(descriptionTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { String($0.subscriptionLimit ?? 0) }
            .drive(limitTextField.rx.text)
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { $0.subscriptionLimit == nil }
            .drive(limitTextField.rx.isHidden)
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { $0.subscriptionLimit == nil ? #imageLiteral(resourceName: "checkboxOn") : #imageLiteral(resourceName: "checkboxOff") }
            .drive(checkboxImageView.rx.image)
            .disposed(by: disposeBag)

        output
            .loadFanPass
            .map { ($0.level ?? 0) == 0 }
            .drive(limitStackView.rx.isHidden)
            .disposed(by: disposeBag)

        output
            .loadFanPass
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

        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}
