//
//  CreateProjectViewController.swift
//  PictionView
//
//  Created by jhseo on 15/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import CropViewController

final class CreateProjectViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var projectTitleTextField: UITextField!
    @IBOutlet weak var projectIdTextField: UITextField!
    @IBOutlet weak var projectUrlLabel: UILabel!
    @IBOutlet weak var wideThumbnailButton: UIButton!
    @IBOutlet weak var thumbnailButton: UIButton!
    @IBOutlet weak var synopsisTextField: UITextField!
    @IBOutlet weak var saveBarButton: UIBarButtonItem!
    @IBOutlet weak var wideThumbnailImageView: UIImageView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var deleteWideThumbnailButton: UIButton!
    @IBOutlet weak var deleteThumbnailButton: UIButton!

    private let chosenThumbnailImage = PublishSubject<UIImage>()
    private let chosenWideThumbnailImage = PublishSubject<UIImage>()

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension CreateProjectViewController: ViewModelBindable {

    typealias ViewModel = CreateProjectViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = CreateProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            inputProjectTitle: projectTitleTextField.rx.text.orEmpty.asDriver(),
            inputProjectId: projectIdTextField.rx.text.orEmpty.asDriver(),
            wideThumbnailBtnDidTap: wideThumbnailButton.rx.tap.asDriver(),
            thumbnailBtnDidTap: thumbnailButton.rx.tap.asDriver(),
            wideThumbnailImageDidPick: chosenWideThumbnailImage.asDriver(onErrorDriveWith: .empty()),
            thumbnailImageDidPick: chosenThumbnailImage.asDriver(onErrorDriveWith: .empty()),
            deleteWideThumbnailBtnDidTap: deleteWideThumbnailButton.rx.tap.asDriver(),
            deleteThumbnailBtnDidTap: deleteThumbnailButton.rx.tap.asDriver(),
            inputSynopsis: synopsisTextField.rx.text.orEmpty.asDriver(),
            saveBtnDidTap: saveBarButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.navigationBar.prefersLargeTitles = false
            })
            .disposed(by: disposeBag)

        output
            .isModify
            .drive(onNext: { [weak self] isModify in
                self?.navigationItem.title = isModify ? "프로젝트 수정 BETA" : "프로젝트 생성 BETA"
                self?.saveBarButton.title = isModify ? "수정" : "등록"
                self?.projectIdTextField.isEnabled = !isModify
                self?.projectIdTextField.textColor = isModify ? UIColor(r: 191, g: 191, b: 191) : .black
            })
            .disposed(by: disposeBag)

        output
            .loadProject
            .drive(onNext: { [weak self] projectInfo in
                self?.projectTitleTextField.text = projectInfo.title
                self?.projectIdTextField.text = projectInfo.uri

                let wideThumbnailWithIC = "\(projectInfo.wideThumbnail ?? "")?w=720&h=360&quality=80&output=webp"
                if let url = URL(string: wideThumbnailWithIC) {
                    self?.wideThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
                } else {
                    self?.wideThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
                }

                let thumbnailWithIC = "\(projectInfo.thumbnail ?? "")?w=720&h=720&quality=80&output=webp"
                if let url = URL(string: thumbnailWithIC) {
                    self?.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                }

                self?.synopsisTextField.text = projectInfo.synopsis
            })
            .disposed(by: disposeBag)

        output
            .projectIdChanged
            .drive(onNext: { [weak self] projectId in
                self?.projectUrlLabel.text = "프로젝트 주소: https://piction.network/project/\(projectId)"
            })
            .disposed(by: disposeBag)

        output
            .openWideThumbnailImagePicker
            .drive(onNext: { [weak self] in
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = UIImagePickerController.SourceType.photoLibrary
                picker.view.tag = 0
                self?.present(picker, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        output
            .openThumbnailImagePicker
            .drive(onNext: { [weak self] in
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = UIImagePickerController.SourceType.photoLibrary
                picker.view.tag = 1
                self?.present(picker, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        output
            .changeWideThumbnail
            .drive(onNext: { [weak self] image in
                if let image = image {
                    self?.wideThumbnailImageView.image = image
                } else {
                    self?.wideThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
                }
            })
            .disposed(by: disposeBag)

        output
            .changeThumbnail
            .drive(onNext: { [weak self] image in
                if let image = image {
                    self?.thumbnailImageView.image = image
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                }
            })
            .disposed(by: disposeBag)

        output
            .popViewController
            .drive(onNext: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { [weak self] status in
                if status {
                    self?.view.makeToastActivity(.center)
                } else {
                    self?.view.hideToastActivity()
                }
            })
            .disposed(by: disposeBag)
        
        output
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
    }
}

extension CreateProjectViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
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
                cropViewController.view.tag = picker.view.tag
                if picker.view.tag == 0 {
                    cropViewController.customAspectRatio = CGSize(width: 1440, height: 450)
                } else {
                    cropViewController.customAspectRatio = CGSize(width: 500, height: 500)
                }

                self?.present(cropViewController, animated: true, completion: nil)
            }
        }
    }
}

extension CreateProjectViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        let imgData = NSData(data: image.jpegData(compressionQuality: 1)!)
        print(imgData.count)
        if imgData.count > (1048576 * 10) {
            Toast.showToast("이미지가 10MB를 초과합니다")
        } else {
            if cropViewController.view.tag == 0 {
                self.chosenWideThumbnailImage.onNext(image)
            } else {
                self.chosenThumbnailImage.onNext(image)
            }
        }
        cropViewController.dismiss(animated: true)
    }
}

extension CreateProjectViewController: KeyboardManagerDelegate {
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
