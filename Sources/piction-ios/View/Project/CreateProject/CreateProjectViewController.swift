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
import WSTagsField
import MobileCoreServices

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
    @IBOutlet weak var privateProjectCheckBoxButton: UIButton!
    @IBOutlet weak var privateProjectCheckBoxImageView: UIImageView!
    @IBOutlet weak var tagsField: WSTagsField! {
        didSet {
            tagsField.font = .systemFont(ofSize: 14)
            tagsField.placeholder = "#태그입력(최대 5개)"
            tagsField.layoutMargins = UIEdgeInsets(top: 6.5, left: 10, bottom: 6.5, right: 10)
            tagsField.contentInset = UIEdgeInsets(top: 2.5, left: 0, bottom: -2.5, right: 0)
            tagsField.spaceBetweenTags = 5.0
            tagsField.spaceBetweenLines = 10.0
            tagsField.tintColor = UIColor(r: 242, g: 242, b: 242)
            tagsField.textColor = UIColor(r: 51, g: 51, b: 51)
            tagsField.selectedColor = UIColor(r: 26, g: 146, b: 255)
            tagsField.fieldTextColor = UIColor(named: "PictionDarkGray") ?? UIColor(r: 51, g: 51, b: 51)
            tagsField.selectedTextColor = .white
            tagsField.acceptTagOption = .space
            tagsField.returnKeyType = .next

            UITextField.appearance().tintColor = UIView().tintColor
        }
    }
    @IBOutlet weak var tagsFieldHeightConstraint: NSLayoutConstraint!

    private let chosenThumbnailImage = PublishSubject<UIImage>()
    private let chosenWideThumbnailImage = PublishSubject<UIImage>()
    private let inputTags = PublishSubject<[String]>()


    var tagsFieldIsActive: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
        self.tabBarController?.tabBar.isHidden = true

        tagsField.onShouldAcceptTag = { [weak self] field in
            let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text != "" && text != "#" {
                if text.first != "#" {
                    self?.tagsField.addTag("#\(text)")
                } else {
                    self?.tagsField.addTag("\(text)")
                }
            }
            return false
        }

        tagsField.onDidAddTag = { [weak self] field, tag in
            self?.inputTags.onNext(self?.tagsField.tags.map { $0.text.replacingOccurrences(of: "#", with: "") } ?? [])
        }

        tagsField.onDidRemoveTag = { [weak self] field, tag in
            self?.inputTags.onNext(self?.tagsField.tags.map { $0.text.replacingOccurrences(of: "#", with: "") } ?? [])
        }

        tagsField.onDidChangeHeightTo = { [weak self] _, height in
            print("HeightTo", height)
            self?.tagsFieldHeightConstraint.constant = height + ((height / 30) * 5)
        }

        tagsField.textDelegate = self

        let config = UIPasteConfiguration(acceptableTypeIdentifiers: [kUTTypeImage as String])
        view.pasteConfiguration = config
    }

    override func paste(itemProviders: [NSItemProvider]) {
        for itemProvider in itemProviders { loadContent(itemProvider) }
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }

    private func controlStatusCheckBox(_ status: String) {
        self.privateProjectCheckBoxImageView.image = status == "HIDDEN" ? #imageLiteral(resourceName: "ic-check") : UIImage()
        self.privateProjectCheckBoxImageView.backgroundColor = status == "HIDDEN" ? UIColor(r: 26, g: 146, b: 255) : UIColor.clear
    }
}

extension CreateProjectViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tagsFieldIsActive = true
    }
}

extension CreateProjectViewController: ViewModelBindable {

    typealias ViewModel = CreateProjectViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = CreateProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            inputProjectTitle: projectTitleTextField.rx.text.orEmpty.asDriver(),
            inputProjectId: projectIdTextField.rx.text.orEmpty.asDriver(),
            wideThumbnailBtnDidTap: wideThumbnailButton.rx.tap.asDriver(),
            thumbnailBtnDidTap: thumbnailButton.rx.tap.asDriver(),
            wideThumbnailImageDidPick: chosenWideThumbnailImage.asDriver(onErrorDriveWith: .empty()),
            thumbnailImageDidPick: chosenThumbnailImage.asDriver(onErrorDriveWith: .empty()),
            deleteWideThumbnailBtnDidTap: deleteWideThumbnailButton.rx.tap.asDriver(),
            deleteThumbnailBtnDidTap: deleteThumbnailButton.rx.tap.asDriver(),
            inputTags: inputTags.asDriver(onErrorDriveWith: .empty()),
            privateProjectCheckBoxBtnDidTap: privateProjectCheckBoxButton.rx.tap.asDriver(),
            inputSynopsis: synopsisTextField.rx.text.orEmpty.asDriver(),
            saveBtnDidTap: saveBarButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
//                self?.tabBarController?.tabBar.isHidden = true
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
//                self?.tabBarController?.tabBar.isHidden = false
            })
            .disposed(by: disposeBag)

        output
            .isModify
            .drive(onNext: { [weak self] isModify in
                self?.navigationItem.title = isModify ? "프로젝트 수정 BETA" : "프로젝트 생성 BETA"
                self?.saveBarButton.title = isModify ? "수정" : "등록"
                self?.projectIdTextField.isEnabled = !isModify
                self?.projectIdTextField.textColor = isModify ? UIColor(r: 191, g: 191, b: 191) : UIColor(named: "PictionDarkGray") ?? UIColor(r: 51, g: 51, b: 51)
            })
            .disposed(by: disposeBag)

        output
            .loadProject
            .drive(onNext: { [weak self] projectInfo in
                self?.projectTitleTextField.text = projectInfo.title
                self?.projectIdTextField.text = projectInfo.uri

                if let wideThumbnail = projectInfo.wideThumbnail {
                    let wideThumbnailWithIC = "\(wideThumbnail)?w=720&h=360&quality=80&output=webp"
                    if let url = URL(string: wideThumbnailWithIC) {
                        self?.wideThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
                        self?.deleteWideThumbnailButton.isHidden = false
                    }
                } else {
                    self?.wideThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
                    self?.deleteWideThumbnailButton.isHidden = true
                }

                if let thumbnail = projectInfo.thumbnail {
                    let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
                    if let url = URL(string: thumbnailWithIC) {
                        self?.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                        self?.deleteThumbnailButton.isHidden = false
                    }
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                    self?.deleteThumbnailButton.isHidden = true
                }

                self?.synopsisTextField.text = projectInfo.synopsis

                self?.controlStatusCheckBox(projectInfo.status ?? "PUBLIC")
                projectInfo.tags?.forEach { self?.tagsField.addTag("#\($0)") }
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
                    self?.deleteWideThumbnailButton.isHidden = false
                } else {
                    self?.wideThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
                    self?.deleteWideThumbnailButton.isHidden = true
                }
            })
            .disposed(by: disposeBag)

        output
            .changeThumbnail
            .drive(onNext: { [weak self] image in
                if let image = image {
                    self?.thumbnailImageView.image = image
                    self?.deleteThumbnailButton.isHidden = false
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                    self?.deleteThumbnailButton.isHidden = true
                }
            })
            .disposed(by: disposeBag)

        output
            .statusChanged
            .drive(onNext: { [weak self] status in
                self?.controlStatusCheckBox(status)
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
            .dismissKeyboard
            .drive(onNext: { [weak self] _ in
                self?.view.endEditing(true)
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
                self?.openCropViewController(image: chosenImage, tag: picker.view.tag)
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
        let viewController = cropViewController.children.first!
        viewController.modalTransitionStyle = .coverVertical
        viewController.presentingViewController?.dismiss(animated: true, completion: nil)
//        cropViewController.dismiss(animated: true)
    }
}

extension CreateProjectViewController: KeyboardManagerDelegate {
    func keyboardManager(_ keyboardManager: KeyboardManager, keyboardWillChangeFrame endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions) {
        guard let endFrame = endFrame else { return }

        if endFrame.origin.y >= SCREEN_H {
            scrollView.contentInset = .zero
            tagsFieldIsActive = false
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.size.height, right: 0)
            if tagsFieldIsActive {
                scrollView.scrollRectToVisible(tagsField.superview!.frame, animated: true)
            }
        }

        UIView.animate(withDuration: duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

extension CreateProjectViewController {
    func openCropViewController(image: UIImage, tag: Int) {
        let cropViewController = CropViewController(image: image)
        cropViewController.delegate = self
        cropViewController.aspectRatioLockEnabled = true
        cropViewController.aspectRatioPickerButtonHidden = true
        cropViewController.view.tag = tag
        if tag == 0 {
            cropViewController.customAspectRatio = CGSize(width: 1440, height: 450)
        } else {
            cropViewController.customAspectRatio = CGSize(width: 500, height: 500)
        }
        self.present(cropViewController, animated: true, completion: nil)
    }

    func openAttachImage(image: UIImage) {
        let alertController = UIAlertController(
        title: "이미지를 어디에 넣을까요?",
        message: nil,
        preferredStyle: UIAlertController.Style.actionSheet)

        let wideThumbnailAction = UIAlertAction(
            title: "와이드",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openCropViewController(image: image, tag: 0)
            })

        let thumbnailAction = UIAlertAction(
            title: "1:1",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openCropViewController(image: image, tag: 1)
            })

        let cancelAction = UIAlertAction(
            title: "취소",
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(wideThumbnailAction)
        alertController.addAction(thumbnailAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    func loadContent(_ itemProvider: NSItemProvider) {
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if error != nil { print("Error loading image. \(error!.localizedDescription)"); return }
                DispatchQueue.main.async {
                    let image = object as! UIImage
                    self.openAttachImage(image: image)
                }
            }
        }
    }
}
