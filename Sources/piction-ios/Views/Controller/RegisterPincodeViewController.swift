//
//  RegisterPincodeViewController.swift
//  PictionSDK
//
//  Created by jhseo on 22/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class RegisterPincodeViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var pincodeTextField: UITextField!
    @IBOutlet weak var pincode1View: UIView!
    @IBOutlet weak var pincode2View: UIView!
    @IBOutlet weak var pincode3View: UIView!
    @IBOutlet weak var pincode4View: UIView!
    @IBOutlet weak var pincode5View: UIView!
    @IBOutlet weak var pincode6View: UIView!
    @IBOutlet weak var closeButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: true, shadow: false)
    }

    private func openRecommendPopup() {
        let alertController = UIAlertController(title: LocalizedStrings.popup_title_pincode_create.localized(), message: LocalizedStrings.msg_pincode_reg_warning.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizedStrings.continue_go.localized(), style: .default) { _ in
        }
        let confirmButton = UIAlertAction(title: LocalizedStrings.pass.localized(), style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }
}

extension RegisterPincodeViewController: ViewModelBindable {

    typealias ViewModel = RegisterPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = RegisterPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.pincodeTextField.becomeFirstResponder()
            })
            .disposed(by: disposeBag)

        output
            .pincodeText
            .drive(onNext: { [weak self] inputPincode in
                switch inputPincode.count {
                case 0:
                    self?.pincode1View.backgroundColor = .pictionLightGray
                    self?.pincode2View.backgroundColor = .pictionLightGray
                    self?.pincode3View.backgroundColor = .pictionLightGray
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 1:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionLightGray
                    self?.pincode3View.backgroundColor = .pictionLightGray
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 2:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionLightGray
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 3:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionLightGray
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 4:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionBlue
                    self?.pincode5View.backgroundColor = .pictionLightGray
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 5:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionBlue
                    self?.pincode5View.backgroundColor = .pictionBlue
                    self?.pincode6View.backgroundColor = .pictionLightGray
                case 6:
                    self?.pincode1View.backgroundColor = .pictionBlue
                    self?.pincode2View.backgroundColor = .pictionBlue
                    self?.pincode3View.backgroundColor = .pictionBlue
                    self?.pincode4View.backgroundColor = .pictionBlue
                    self?.pincode5View.backgroundColor = .pictionBlue
                    self?.pincode6View.backgroundColor = .pictionBlue
                    self?.pincodeTextField.text = ""
                    self?.openConfirmPincodeViewController(inputPincode: inputPincode)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .openRecommendPopup
            .drive(onNext: { [weak self] in
                self?.openRecommendPopup()
            })
            .disposed(by: disposeBag)
    }
}

extension RegisterPincodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (string.count == 0) {
            return true
        }

        if (textField == self.pincodeTextField) {
            let cs = CharacterSet(charactersIn: "0123456789")
            let filtered = string.components(separatedBy: cs).filter {  !$0.isEmpty }
            let str = filtered.joined(separator: "")

            return (string != str)
        }
        return true
    }
}
