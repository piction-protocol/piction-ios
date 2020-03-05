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

// MARK: - UIViewController
final class ChangeMyInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var emailUnderlineView: UIView!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userNameUnderlineView: UIView!
    @IBOutlet weak var pictureImageButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var emailErrorLabel: UILabel!

    private let chosenImage = PublishSubject<UIImage?>() // image 선택됐을 때 Observable
    private let password = PublishSubject<String?>() // password 입력 확인 Observable

    override func viewDidLoad() {
        super.viewDidLoad()

        // present 타입의 경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ChangeMyInfoViewController: ViewModelBindable {

    typealias ViewModel = ChangeMyInfoViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = ChangeMyInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            emailTextFieldDidInput: emailTextField.rx.text.orEmpty.asDriver(), // emailTextField 입력 시
            userNameTextFieldDidInput: userNameTextField.rx.text.orEmpty.asDriver(), // 닉네임 TextField 입력 시
            pictureImageBtnDidTap: pictureImageButton.rx.tap.asDriver(), // 프로필 이미지 눌렀을 때
            pictureImageDidPick: chosenImage.asDriver(onErrorDriveWith: .empty()), // 이미지 picker에서 이미지 선택 했을 때
            cancelBtnDidTap: cancelBarButton.rx.tap.asDriver(), // 취소 버튼 눌렀을 때
            saveBtnDidTap: saveButton.rx.tap.asDriver(), // 저장 버튼 눌렀을 때
            password: password.asDriver(onErrorDriveWith: .empty()) // password 팝업에서 password 입력 시
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에
        output
            .viewWillAppear
            .drive()
            .disposed(by: disposeBag)

        // 화면이 사라지기전에 viewModel에서 keyboard를 숨기고 disposed하기 위함
        output
            .viewWillDisappear
            .drive()
            .disposed(by: disposeBag)

        // 유저 정보를 불러와서 설정
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

        // 프로필 이미지 버튼 눌렀을 때
        output
            .pictureBtnAction
            .drive(onNext: { [weak self] in
                self?.profileImagePopup()
            })
            .disposed(by: disposeBag)

        // 프로필 이미지 변경
        output
            .changePicture
            .map { $0 ?? #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500") }
            .drive(profileImageView.rx.image)
            .disposed(by: disposeBag)

        // 저장 버튼 활성/비활성화
        output
            .enableSaveButton
            .drive(onNext: { [weak self] isEnabled in
                self?.saveButton.isEnabled = isEnabled
                if isEnabled {
                    self?.saveButton.setTitleColor(.white, for: .normal)
                    self?.saveButton.backgroundColor = .pictionDarkGray
                } else {
                    self?.saveButton.setTitleColor(.pictionGray, for: .normal)
                    self?.saveButton.backgroundColor = .pictionLightGray
                }
            })
            .disposed(by: disposeBag)

        // keyboard가 나타나거나 사라질때 scrollView의 크기 조정
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

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        // 에러 메시지를 각 field 밑에 출력
        output
            .showErrorLabel
            .drive(onNext: { [weak self] errorMessage in
                self?.password.onNext(nil)
                self?.view.endEditing(true)
                self?.emailErrorLabel.isHidden = false
                self?.emailErrorLabel.text = errorMessage
            })
            .disposed(by: disposeBag)

        // 에러 메시지가 없거나 입력 시작 시 에러 메시지 숨김
        output
            .hideErrorLabel
            .drive(onNext: { [weak self] in
                self?.emailErrorLabel.isHidden = true
                self?.emailErrorLabel.text = ""
            })
            .disposed(by: disposeBag)

        // 정보가 변경되었는데 취소 버튼 눌렀을 때 경고 팝업 출력
        output
            .openWarningPopup
            .drive(onNext: { [weak self] in
                self?.warningPopup()
            })
            .disposed(by: disposeBag)

        // 패스워드 입력 팝업 출력
        output
            .openPasswordPopup
            .drive(onNext: { [weak self] in
                self?.checkPasswordPopup()
            })
            .disposed(by: disposeBag)

        // 토스트 메시지 출력 (키보드에 가리기 때문에 키보드 숨긴 후 출력)
        output
            .toastMessage
            .do(onNext: { [weak self] message in
                self?.password.onNext(nil)
                self?.view.endEditing(true)
            })
            .showToast()
            .disposed(by: disposeBag)
    }
}

// MARK: - IBAction
extension ChangeMyInfoViewController {
    // 화면 tap 시 키보드 숨기기
    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate
extension ChangeMyInfoViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // imagePicker에서 취소했을 때
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    // imagePicker 출력
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

// MARK: - CropViewControllerDelegate
extension ChangeMyInfoViewController: CropViewControllerDelegate {
    // cropViewController에서 이미지 선택 시
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        let imgData = NSData(data: image.jpegData(compressionQuality: 1)!)
        print(imgData.count)
        if imgData.count > (1048576 * 10) {
            Toast.showToast(LocalizationKey.str_image_size_exceeded.localized())
        } else {
            self.chosenImage.onNext(image)
        }
        let viewController = cropViewController.children.first!
        viewController.modalTransitionStyle = .coverVertical
        viewController.presentingViewController?.dismiss(animated: true, completion: nil)
//        cropViewController.dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension ChangeMyInfoViewController: UITextFieldDelegate {
    // textField에 입력을 시작할 때
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === userNameTextField {
            self.userNameUnderlineView.backgroundColor = .pictionBlue
        } else if textField === emailTextField {
            self.emailUnderlineView.backgroundColor = .pictionBlue
        }
    }

    // textField에 입력이 끝났을 때
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.userNameUnderlineView.backgroundColor = .pictionDarkGrayDM
        self.emailUnderlineView.backgroundColor = .pictionDarkGrayDM
    }
}

// MARK: - Private Method
extension ChangeMyInfoViewController {
    // 프로필 이미지 변경, 삭제 팝업 (action sheet)
    private func profileImagePopup() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel)
        let deleteButton = UIAlertAction(title: LocalizationKey.str_delete_profile_image.localized(), style: .destructive) { [weak self] _ in
            self?.chosenImage.onNext(nil)
        }
        let updateButton = UIAlertAction(title: LocalizationKey.str_change_profile_image.localized(), style: .destructive) { [weak self] _ in
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

    // 정보가 변경되었는데 취소 버튼 눌렀을 때 경고 팝업
    private func warningPopup() {
        let alert = UIAlertController(title: nil, message: LocalizationKey.msg_title_confirm.localized(), preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default, handler: { [weak self] action in
            self?.dismiss(animated: true)
        })
        alert.addAction(okAction)

        let cancelAction = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel, handler : nil)
        alert.addAction(cancelAction)

        present(alert, animated: false, completion: nil)
    }

    // 패스워드 확인 팝업
    private func checkPasswordPopup() {
        let alert = UIAlertController(title: LocalizationKey.authenticates.localized(), message: LocalizationKey.msg_title_confirm_password.localized(), preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default, handler: { [weak self] action in

            let inputPassword = alert.textFields?.first?.text ?? ""

            self?.password.onNext(inputPassword)
        })
        alert.addAction(okAction)

        let cancelAction = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel, handler : nil)
        alert.addAction(cancelAction)

        alert.addTextField(configurationHandler: configurationPasswordTextField)

        present(alert, animated: false, completion: nil)
    }

    // 패스워드 팝업에 textField 추가
    private func configurationPasswordTextField(textField: UITextField!) {
        textField.placeholder = ""
        textField.isSecureTextEntry = true
    }
}
