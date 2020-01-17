//
//  ChangeMyInfoViewController.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import CropViewController

final class ChangeMyInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userNameUnderlineView: UIView!
    @IBOutlet weak var pictureImageButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!

    private let chosenImage = PublishSubject<UIImage?>()
    private let password = PublishSubject<String?>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension ChangeMyInfoViewController: ViewModelBindable {

    typealias ViewModel = ChangeMyInfoViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = ChangeMyInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            emailTextFieldDidInput: emailTextField.rx.text.orEmpty.asDriver(),
            userNameTextFieldDidInput: userNameTextField.rx.text.orEmpty.asDriver(),
            pictureImageBtnDidTap: pictureImageButton.rx.tap.asDriver(),
            pictureImageDidPick: chosenImage.asDriver(onErrorDriveWith: .empty()),
            cancelBtnDidTap: cancelBarButton.rx.tap.asDriver(),
            saveBtnDidTap: saveButton.rx.tap.asDriver(),
            password: password.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { _ in
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                if let profileImage = userInfo.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"

                    if let url = URL(string: userPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"))
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                }
                self?.emailTextField.text = userInfo.email
                self?.userNameTextField.text = userInfo.username
            })
            .disposed(by: disposeBag)

        output
            .pictureBtnAction
            .drive(onNext: { [weak self] in
                self?.profileImagePopup()
            })
            .disposed(by: disposeBag)

        output
            .changePicture
            .drive(onNext: { [weak self] image in
                if image == nil {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                } else {
                    self?.profileImageView.image = image
                }
            })
            .disposed(by: disposeBag)

        output
            .enableSaveButton
            .filter { $0 }
            .drive(onNext: { [weak self] _ in
                self?.saveButton.isEnabled = true
                self?.saveButton.setTitleColor(.white, for: .normal)
                self?.saveButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
            })
            .disposed(by: disposeBag)

        output
            .keyboardWillChangeFrame
            .drive(onNext: { [weak self] changedFrameInfo in
                guard
                    let `self` = self,
                    let endFrame = changedFrameInfo.endFrame
                else { return }

                if endFrame.origin.y >= SCREEN_H {
                    self.scrollView.contentInset = .zero
                } else {
                    self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.size.height, right: 0)
                }

                UIView.animate(withDuration: changedFrameInfo.duration, animations: {
                    self.view.layoutIfNeeded()
                })
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .openWarningPopup
            .drive(onNext: { [weak self] in
                self?.warningPopup()
            })
            .disposed(by: disposeBag)

        output
            .openPasswordPopup
            .drive(onNext: { [weak self] in
                self?.checkPasswordPopup()
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { [weak self] message in
                self?.password.onNext(nil)
                self?.view.endEditing(true)
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
    }
}

extension ChangeMyInfoViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        if let chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            dismiss(animated: true) { [weak self] in
                let cropViewController = CropViewController(image: chosenImage)
                cropViewController.delegate = self
                cropViewController.aspectRatioLockEnabled = true
                cropViewController.aspectRatioPickerButtonHidden = true
                cropViewController.customAspectRatio = CGSize(width: 500, height: 500)
                
                self?.present(cropViewController, animated: true, completion: nil)
            }
        }
    }
}

extension ChangeMyInfoViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        let imgData = NSData(data: image.jpegData(compressionQuality: 1)!)
        print(imgData.count)
        if imgData.count > (1048576 * 10) {
            Toast.showToast(LocalizedStrings.str_image_size_exceeded.localized())
        } else {
            self.chosenImage.onNext(image)
        }
        let viewController = cropViewController.children.first!
        viewController.modalTransitionStyle = .coverVertical
        viewController.presentingViewController?.dismiss(animated: true, completion: nil)
//        cropViewController.dismiss(animated: true)
    }
}

extension ChangeMyInfoViewController {
    private func profileImagePopup() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cancelButton = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel)
        let deleteButton = UIAlertAction(title: LocalizedStrings.str_delete_profile_image.localized(), style: .destructive) { [weak self] _ in
            self?.chosenImage.onNext(nil)
        }
        let updateButton = UIAlertAction(title: LocalizedStrings.str_change_profile_image.localized(), style: .destructive) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = UIImagePickerController.SourceType.photoLibrary

            self?.present(picker, animated: true, completion: nil)
        }

        alertController.addAction(updateButton)
        alertController.addAction(deleteButton)
        alertController.addAction(cancelButton)

        if let topController = UIApplication.topViewController() {
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                alertController.modalPresentationStyle = .popover
                if let popover = alertController.popoverPresentationController {
                    popover.permittedArrowDirections = .up
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(x: SCREEN_W / 2, y: self.statusHeight + self.navigationHeight + pictureImageButton.frame.origin.y + pictureImageButton.frame.height, width: 0, height: 0)
                }
            }
            topController.present(alertController, animated: true, completion: nil)
        }
    }

    private func warningPopup() {
        let alert = UIAlertController(title: nil, message: LocalizedStrings.msg_title_confirm.localized(), preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizedStrings.confirm.localized(), style: .default, handler: { [weak self] action in
            self?.dismiss(animated: true)
        })
        alert.addAction(okAction)

        let cancelAction = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel, handler : nil)
        alert.addAction(cancelAction)

        present(alert, animated: false, completion: nil)
    }

    private func checkPasswordPopup() {
        let alert = UIAlertController(title: LocalizedStrings.authenticates.localized(), message: LocalizedStrings.msg_title_confirm_password.localized(), preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizedStrings.confirm.localized(), style: .default, handler: { [weak self] action in

            let inputPassword = alert.textFields?.first?.text ?? ""

            self?.password.onNext(inputPassword)
        })
        alert.addAction(okAction)

        let cancelAction = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel, handler : nil)
        alert.addAction(cancelAction)

        alert.addTextField(configurationHandler: configurationPasswordTextField)

        present(alert, animated: false, completion: nil)
    }

    private func configurationPasswordTextField(textField: UITextField!){
        textField.placeholder = ""
        textField.isSecureTextEntry = true
    }
}

extension ChangeMyInfoViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === userNameTextField {
            self.userNameUnderlineView.backgroundColor = .pictionBlue
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === userNameTextField {
            self.userNameUnderlineView.backgroundColor = .pictionDarkGrayDM
        }
    }
}
