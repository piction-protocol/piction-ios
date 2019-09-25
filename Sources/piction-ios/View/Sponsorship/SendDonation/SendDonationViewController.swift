//
//  SendDonationViewController.swift
//  PictionSDK
//
//  Created by jhseo on 19/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import PictionSDK

final class SendDonationViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var pxlLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var amountUnderlineView: UIView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var sendButtonDescriptionLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageViewExtension!

    @IBOutlet weak var amountUnderlineHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    private let authSuccessWithPincode = PublishSubject<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
    }

    private func openConfirmDonationViewController(loginId: String, sendAmount: Int) {
        let vc = ConfirmDonationViewController.make(loginId: loginId, sendAmount: sendAmount)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openCheckPincodeViewController() {
        let vc = CheckPincodeViewController.make(style: .check)
        vc.delegate = self
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func errorPopup(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: "확인", style: .default, handler: { action in
        })
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }
}

extension SendDonationViewController: ViewModelBindable {
    typealias ViewModel = SendDonationViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = SendDonationViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            amountTextFieldDidInput: amountTextField.rx.text.orEmpty.asDriver(),
            sendBtnDidTap: sendButton.rx.tap.asDriver(),
            authSuccessWithPincode: authSuccessWithPincode.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.navigationBar.prefersLargeTitles = false
                self?.tabBarController?.tabBar.isHidden = true
                self?.amountTextField.becomeFirstResponder()
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] _ in
                self?.tabBarController?.tabBar.isHidden = false
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                let userPictureWithIC = "\(userInfo.picture ?? "")?w=240&h=240&quality=80&output=webp"

                if let url = URL(string: userPictureWithIC) {
                    self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                }
                self?.loginIdLabel.text = "@\(userInfo.loginId ?? "")"
            })
            .disposed(by: disposeBag)

        output
            .walletInfo
            .drive(onNext: { [weak self] walletInfo in
                self?.pxlLabel.text = "\(walletInfo.amount.commaRepresentation) PXL 보유 중"
            })
            .disposed(by: disposeBag)

        output
            .enableSendButton
            .drive(onNext: { [weak self] status in
                self?.sendButton.isEnabled = status
                self?.sendButtonDescriptionLabel.textColor = status ? .white : UIColor(r: 191, g: 191, b: 191)
                self?.sendButton.backgroundColor = status ? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 242, g: 242, b: 242)

                if status {
                    self?.amountUnderlineHeightConstraint.constant = 3
                    self?.amountUnderlineView.layer.shadowOpacity = 0.2
                    self?.amountUnderlineView.layer.shadowColor = UIColor(r: 26, g: 146, b: 255).cgColor
                    self?.amountUnderlineView.layer.shadowRadius = 4
                    self?.amountUnderlineView.layer.shadowOffset = CGSize(width: 0, height: 1)
                    self?.amountUnderlineView.layer.masksToBounds = false
                } else {
                    self?.amountUnderlineHeightConstraint.constant = 1
                    self?.amountUnderlineView.layer.shadowOpacity = 0
                    self?.amountUnderlineView.layer.shadowColor = UIColor.clear.cgColor
                    self?.amountUnderlineView.layer.shadowRadius = 0
                    self?.amountUnderlineView.layer.shadowOffset = CGSize(width: 0, height: 0)
                    self?.amountUnderlineView.layer.masksToBounds = true
                }
            })
            .disposed(by: disposeBag)

        output
            .openConfirmDonationViewController
            .drive(onNext: { [weak self] (loginId, sendAmount) in
                self?.openConfirmDonationViewController(loginId: loginId, sendAmount: sendAmount)
            })
            .disposed(by: disposeBag)

        output
            .openCheckPincodeViewController
            .drive(onNext: { [weak self] _ in
                self?.openCheckPincodeViewController()
            })
            .disposed(by: disposeBag)

        output
            .openErrorPopup
            .drive(onNext: { [weak self] message in
                self?.errorPopup(message: message)
            })
            .disposed(by: disposeBag)
    }
}

extension SendDonationViewController: KeyboardManagerDelegate {
    func keyboardManager(_ keyboardManager: KeyboardManager, keyboardWillChangeFrame endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions) {
        guard let endFrame = endFrame else { return }

        if endFrame.origin.y >= SCREEN_H {
            bottomConstraint.constant = 0
        } else {
            bottomConstraint.constant = endFrame.size.height
        }

        UIView.animate(withDuration: duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

extension SendDonationViewController: CheckPincodeDelegate {
    func authSuccess() {
        self.authSuccessWithPincode.onNext(())
    }
}
