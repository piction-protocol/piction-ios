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

// MARK: - UIViewController
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

        // present 타입의경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: true, shadow: false)
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension RegisterPincodeViewController: ViewModelBindable {
    typealias ViewModel = RegisterPincodeViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = RegisterPincodeViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            pincodeTextFieldDidInput: pincodeTextField.rx.text.orEmpty.asDriver(), // pincode textfield에 입력했을 때
            closeBtnDidTap: closeButton.rx.tap.asDriver() // 닫기 버튼을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                // 키보드 출력
                self?.pincodeTextField.becomeFirstResponder()
            })
            .disposed(by: disposeBag)

        // pincode textfield에 값이 입력될 때
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

                    // 등록한 pincode를 가지고 pincode 확인 화면으로 push
                    self?.openView(type: .confirmPincode(inputPincode: inputPincode), openType: .push)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        // 닫기 버튼 누르면 pincode 설정 권장 팝업 출력
        output
            .openRecommendPopup
            .drive(onNext: { [weak self] in
                self?.openRecommendPopup()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UITextFieldDelegate
extension RegisterPincodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (string.count == 0) {
            return true
        }

        // 숫자만 입력 가능하도록 함
        if (textField == self.pincodeTextField) {
            let cs = CharacterSet(charactersIn: "0123456789")
            let filtered = string.components(separatedBy: cs).filter {  !$0.isEmpty }
            let str = filtered.joined(separator: "")

            return (string != str)
        }
        return true
    }
}

// MARK: - Private Method
extension RegisterPincodeViewController {
    // pincode 설정 권장 팝업
    private func openRecommendPopup() {
        let alertController = UIAlertController(title: LocalizationKey.popup_title_pincode_create.localized(), message: LocalizationKey.msg_pincode_reg_warning.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.continue_go.localized(), style: .default)
        let confirmButton = UIAlertAction(title: LocalizationKey.pass.localized(), style: .default) { _ in
            self.dismiss(animated: true)
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }
}
