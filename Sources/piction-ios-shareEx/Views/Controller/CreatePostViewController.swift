//
//  CreatePostViewController.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK
import Toast_Swift
import MobileCoreServices

final class CreatePostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var imageStackView: UIStackView!

    @IBOutlet weak var projectButton: UIButton!
    @IBOutlet weak var seriesButton: UIButton!
    @IBOutlet weak var statusButton: UIButton!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!

    private let selectedProject = PublishSubject<ProjectModel?>()
    private let selectedSeries = PublishSubject<SeriesModel?>()
    private let selectedStatus = PublishSubject<String>()
    private let contentText = PublishSubject<String>()
    private let selectedImages = PublishSubject<[UIImage]>()

    var textViewIsActive: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let accessToken = KeychainManager.get(key: .accessToken)
        PictionManager.setToken(accessToken)
    }

    func loadContents() {
        getExtensionItemText(completion: { text in
            if let text = text {
                self.contentText.onNext(text)
            } else {
                self.contentText.onNext("")
            }
        })
        getExtensionItemImage(completion: { images in
            if images.count > 0 {
                self.selectedImages.onNext(images)
                self.imageStackView.isHidden = false
            } else {
                self.imageStackView.isHidden = true
            }
        })
    }

    func hideExtensionWithCompletionHandler(completion: @escaping (Bool) -> Void) {
        UIView.animate(withDuration: 0.20, animations: {
            self.navigationController!.view.transform = CGAffineTransform(translationX: 0, y: self.navigationController!.view.frame.size.height)
        }, completion: completion)
    }

    func openProjectListViewController(with projects: [ProjectModel]) {
        let vc = ProjectListViewController.make(projects: projects)
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        self.present(nav, animated: true)
    }

    func openManageSeriesViewController(uri: String) {
        let vc = ManageSeriesViewController.make(uri: uri)
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        self.present(nav, animated: true)
    }

    func openStatusActionSheet() {
        let alertController = UIAlertController(
        title: nil,
        message: nil,
        preferredStyle: UIAlertController.Style.actionSheet)

        let publicAction = UIAlertAction(
            title: LocalizationKey.str_post_status_public.localized(),
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.selectedStatus.onNext("PUBLIC")
            })

        let membershipAction = UIAlertAction(
            title: LocalizationKey.str_post_status_membership.localized(),
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.selectedStatus.onNext("MEMBERSHIP")
            })

        let privateAction = UIAlertAction(
            title: LocalizationKey.str_post_status_private.localized(),
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.selectedStatus.onNext("PRIVATE")
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(publicAction)
        alertController.addAction(membershipAction)
        alertController.addAction(privateAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    func dismissPopup(message: String?) {
        let alertMessage = message != nil ? message : LocalizationKey.str_cancel_creation_post.localized()
        let alertController = UIAlertController(title: nil, message: alertMessage, preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .default) { _ in
        }
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default) { [weak self] _ in
            self?.hideExtensionWithCompletionHandler(completion: { [weak self] (Bool) -> Void in
                self?.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
            })
        }

        if message == nil {
            alertController.addAction(cancelButton)
        }
        alertController.addAction(confirmButton)

        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }

    func getExtensionItemText(completion: @escaping (String?) -> Void) {
        var textContent: String?

        let extensionItems = extensionContext?.inputItems as! [NSExtensionItem]
        for extensionItem in extensionItems {
            if let itemProviders = extensionItem.attachments {
                for (index, element) in itemProviders.enumerated() {
                    if element.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                        element.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (result, error) in
                            textContent = result as? String

                            if index >= itemProviders.count - 1 {
                                completion(textContent)
                            }
                        }
                    }
                }
            }
        }
    }

    func getExtensionItemImage(completion: @escaping ([UIImage]) -> Void) {
        var imageContent: [UIImage] = []

        let extensionItems = extensionContext?.inputItems as! [NSExtensionItem]
        for extensionItem in extensionItems {
            if let itemProviders = extensionItem.attachments {
                for (index, element) in itemProviders.enumerated() {
                    if element.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        element.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (imageURL, error) in
                            if let imageURL = imageURL as? URL {
                                if let image = UIImage(data: try! Data(contentsOf: imageURL)) {
                                    imageContent.append(image)
                                }
                            }
                            if index >= itemProviders.count - 1 {
                                completion(imageContent)
                            }
                        }
                    }
                }
            }
        }
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, UIImage>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, UIImage>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: CreatePostCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model, index: indexPath.row)
                return cell
        })
    }
}

extension CreatePostViewController: ViewModelBindable {
    typealias ViewModel = CreatePostViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CreatePostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            inputTitle: titleTextField.rx.text.orEmpty.asDriver(),
            contentText: contentText.asDriver(onErrorDriveWith: .empty()),
            selectedImages: selectedImages.asDriver(onErrorDriveWith: .empty()),
            projectBtnDidTap: projectButton.rx.tap.asDriver(),
            selectedProject: selectedProject.asDriver(onErrorDriveWith: .empty()),
            seriesBtnDidTap: seriesButton.rx.tap.asDriver(),
            selectedSeries: selectedSeries.asDriver(onErrorDriveWith: .empty()),
            statusBtnDidTap: statusButton.rx.tap.asDriver(),
            selectedStatus: selectedStatus.asDriver(onErrorDriveWith: .empty()),
            saveBtnDidTap: saveButton.rx.tap.asDriver(),
            cancelBtnDidTap: cancelButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                FirebaseManager.screenName("공유_포스트작성")
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { _ in
            })
            .disposed(by: disposeBag)

        output
            .loadContents
            .drive(onNext: { [weak self] _ in
                self?.loadContents()
            })
            .disposed(by: disposeBag)

        output
            .openProjectListViewController
            .drive(onNext: { [weak self] projects in
                self?.openProjectListViewController(with: projects)
            })
            .disposed(by: disposeBag)

        output
            .selectedProject
            .drive(onNext: { [weak self] project in
                self?.projectButton.setTitle(project?.title ?? LocalizationKey.str_select_project.localized(), for: .normal)
                self?.projectButton.setTitleColor(project != nil ? .pictionDarkGrayDM : .placeHolderColor, for: .normal)
            })
            .disposed(by: disposeBag)

        output
            .openManageSeriesViewController
            .drive(onNext: { [weak self] uri in
                self?.openManageSeriesViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .selectedSeries
            .drive(onNext: { [weak self] series in
                self?.seriesButton.setTitle(series?.name ?? LocalizationKey.str_select_series.localized(), for: .normal)
                self?.seriesButton.setTitleColor(series != nil ? .pictionDarkGrayDM : .placeHolderColor, for: .normal)
            })
            .disposed(by: disposeBag)

        output
            .openStatusActionSheet
            .drive(onNext: { [weak self] in
                self?.openStatusActionSheet()
            })
            .disposed(by: disposeBag)

        output
            .selectedStatus
            .drive(onNext: { [weak self] status in

                var statusName: String {
                    switch status {
                    case "PUBLIC":
                        return LocalizationKey.str_post_status_public.localized()
                    case "MEMBERSHIP":
                        return LocalizationKey.str_post_status_membership.localized()
                    case "PRIVATE":
                        return LocalizationKey.str_post_status_private.localized()
                    default:
                        return LocalizationKey.str_post_status_public.localized()
                    }
                }
                self?.statusButton.setTitle(statusName, for: .normal)
            })
            .disposed(by: disposeBag)

        output
            .selectedImages
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .contentText
            .drive(onNext: { [weak self] text in
                if text != LocalizationKey.str_post_content.localized() {
                    self?.textView.textColor = .pictionDarkGrayDM
                }
                self?.textView.text = text
            })
            .disposed(by: disposeBag)

        output
            .enableSaveButton
            .drive(onNext: { [weak self] _ in
                self?.saveButton.isEnabled = true
            })
            .disposed(by: disposeBag)

        output
            .keyboardWillChangeFrame
            .drive(onNext: { [weak self] changedFrameInfo in
                guard
                    let `self` = self,
                    let endFrame = changedFrameInfo.endFrame
                else { return }

                DispatchQueue.main.async {
                    if endFrame.origin.y >= self.view.frame.size.height {
                        self.scrollView.contentInset = .zero
                        self.textViewIsActive = false
                    } else {
                        self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.size.height, right: 0)

                        if self.textViewIsActive {
                            self.scrollView.scrollRectToVisible(self.textView.superview!.frame, animated: true)
                        }
                    }

                    UIView.animate(withDuration: changedFrameInfo.duration, animations: {
                        self.view.layoutIfNeeded()
                    })
                }
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.dismissPopup(message: message)
            })
            .disposed(by: disposeBag)

        output
            .toastMessage
            .drive(onNext: { [weak self] message in
                self?.view.endEditing(true)
                self?.view.makeToast(message)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { [weak self] status in
                self?.projectButton.isEnabled = false
                self?.projectButton.setTitleColor(UIColor.placeHolderColor, for: .normal)
                if status {
                    self?.view.makeToastActivity(.center)
                } else {
                    self?.view.hideToastActivity()
                }
            })
            .disposed(by: disposeBag)
    }
}

extension CreatePostViewController: ProjectListDelegate {
    func selectProject(with project: ProjectModel?) {
        selectedProject.onNext(project)
        selectedSeries.onNext(nil)
    }
}

extension CreatePostViewController: ManageSeriesDelegate {
    func selectSeries(with series: SeriesModel?) {
        selectedSeries.onNext(series)
    }
}

extension CreatePostViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        textViewIsActive = true
        if textView.text == LocalizationKey.str_post_content.localized() {
            textView.text = ""
            textView.textColor = .pictionDarkGrayDM
        } else if textView.text == "" {
            textView.text = LocalizationKey.str_post_content.localized()
            textView.textColor = UIColor.placeHolderColor
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = LocalizationKey.str_post_content.localized()
            textView.textColor = UIColor.placeHolderColor
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        self.contentText.onNext(textView.text)
    }
}
