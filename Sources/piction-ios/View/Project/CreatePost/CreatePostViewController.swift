//
//  CreatePostViewController.swift
//  PictionView
//
//  Created by jhseo on 15/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import Aztec
import Gridicons
import CropViewController
import AVKit
import SafariServices

final class CreatePostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var postTitleTextField: UITextField!
    @IBOutlet weak var postContentTextView: UITextView!
    @IBOutlet weak var contentView: UIView!

    @IBOutlet weak var coverImageButton: UIButton!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var deleteCoverImageButton: UIButton!
    @IBOutlet weak var forAllCheckboxButton: UIButton!
    @IBOutlet weak var forAllCheckboxImageView: UIImageView!
    @IBOutlet weak var forSubscriptionCheckboxButton: UIButton!
    @IBOutlet weak var forSubscriptionCheckboxImageView: UIImageView!
    @IBOutlet weak var saveBarButton: UIBarButtonItem!

    private let chosenCoverImage = PublishSubject<UIImage>()
    private let chosenContentImage = PublishSubject<UIImage>()

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    fileprivate var mediaErrorMode = false

    fileprivate(set) lazy var formatBar: Aztec.FormatBar = {
        return self.createToolbar()
    }()

    private var richTextView: TextView {
        get {
            return editorView.richTextView
        }
    }

    private var htmlTextView: UITextView {
        get {
            return editorView.htmlTextView
        }
    }

    fileprivate(set) lazy var editorView: Aztec.EditorView = {
        let defaultHTMLFont: UIFont

        if #available(iOS 11, *) {
            defaultHTMLFont = UIFontMetrics.default.scaledFont(for: Constants.defaultContentFont)
        } else {
            defaultHTMLFont = Constants.defaultContentFont
        }

        var style = ParagraphStyle()
        style.lineSpacing = 0

        let editorView = Aztec.EditorView(
            defaultFont: Constants.defaultContentFont,
            defaultHTMLFont: defaultHTMLFont,
            defaultParagraphStyle: style,
            defaultMissingImage: Constants.defaultMissingImage)

        editorView.clipsToBounds = false


        setupHTMLTextView(editorView.htmlTextView)
        setupRichTextView(editorView.richTextView)

        return editorView
    }()

    var scrollableItemsForToolbar: [FormatBarItem] {
        return [
            makeToolbarButton(identifier: .bold),
            makeToolbarButton(identifier: .italic),
            makeToolbarButton(identifier: .underline),
            makeToolbarButton(identifier: .link),
            makeToolbarButton(identifier: .media),
            makeToolbarButton(identifier: .more),
            makeToolbarButton(identifier: .sourcecode)
        ]
    }

    private let formattingIdentifiersWithOptions: [FormattingIdentifier] = [.orderedlist, .unorderedlist]

    private func formattingIdentifierHasOptions(_ formattingIdentifier: FormattingIdentifier) -> Bool {
        return formattingIdentifiersWithOptions.contains(formattingIdentifier)
    }

    fileprivate var currentSelectedAttachment: MediaAttachment?

    override func viewDidLoad() {
        super.viewDidLoad()

        contentView.addSubview(editorView)
        editorView.setHTML("")
        editorView.isScrollEnabled = false

        ImageAttachment.defaultAppearance.imageInsets = UIEdgeInsets.zero
//        MediaAttachment.defaultAppearance.

        KeyboardManager.shared.delegate = self

        NSLayoutConstraint.activate([
            editorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            editorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            editorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0)
        ])
    }

    private func controlRequiredFanPass(_ fanPassId: Int?) {
        if fanPassId != nil {
            self.forAllCheckboxImageView.image = UIImage()
            self.forAllCheckboxImageView.backgroundColor = UIColor.white
            self.forSubscriptionCheckboxImageView.image = #imageLiteral(resourceName: "ic-check")
            self.forSubscriptionCheckboxImageView.backgroundColor = UIColor(r: 26, g: 146, b: 255)
        } else {
            self.forSubscriptionCheckboxImageView.image = UIImage()
            self.forSubscriptionCheckboxImageView.backgroundColor = UIColor.white
            self.forAllCheckboxImageView.image = #imageLiteral(resourceName: "ic-check")
            self.forAllCheckboxImageView.backgroundColor = UIColor(r: 26, g: 146, b: 255)
        }
    }

    @IBAction func tapGesture(_ sender: Any) {
        view.endEditing(true)
    }
}

extension CreatePostViewController: ViewModelBindable {

    typealias ViewModel = CreatePostViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = CreatePostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            inputPostTitle: postTitleTextField.rx.text.orEmpty.asDriver(),
            inputContent: richTextView.rx.text.orEmpty.map { _ in self.editorView.getHTML() }.asDriver(onErrorDriveWith: .empty()),
            contentImageDidPick: chosenContentImage.asDriver(onErrorDriveWith: .empty()),
            coverImageBtnDidTap: coverImageButton.rx.tap.asDriver(),
            coverImageDidPick: chosenCoverImage.asDriver(onErrorDriveWith: .empty()),
            deleteCoverImageBtnDidTap: deleteCoverImageButton.rx.tap.asDriver(),
            forAllCheckBtnDidTap: forAllCheckboxButton.rx.tap.asDriver(),
            forSubscriptionCheckBtnDidTap: forSubscriptionCheckboxButton.rx.tap.asDriver(),
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
                self?.navigationItem.title = isModify ? "포스트 수정 BETA" : "포스트 생성 BETA"
                self?.saveBarButton.title = isModify ? "수정" : "등록"
            })
            .disposed(by: disposeBag)

        output
            .loadPostInfo
            .drive(onNext: { [weak self] (postInfo, content) in
                self?.postTitleTextField.text = postInfo.title
                self?.editorView.setHTML(content)

                let coverImageWithIC = "\(postInfo.cover ?? "")?w=656&h=246&quality=80&output=webp"
                if let url = URL(string: coverImageWithIC) {
                    self?.coverImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"))
                } else {
                    self?.coverImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
                }
                self?.controlRequiredFanPass(postInfo.fanPass?.id)
            })
            .disposed(by: disposeBag)

        output
            .uploadContentImage
            .drive(onNext: { [weak self] (url, image) in
                guard let `self` = self else { return }
                guard let url = URL(string: url) else { return }

                let fileURL = url//self.saveToDisk(image: image)

                let attachment = self.richTextView.replaceWithImage(at: self.richTextView.selectedRange, sourceURL: fileURL, placeHolderImage: image)
                attachment.alignment = .none
            })
            .disposed(by: disposeBag)

        output
            .openCoverImagePicker
            .drive(onNext: { [weak self] in
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = UIImagePickerController.SourceType.photoLibrary
                picker.view.tag = 1
                self?.present(picker, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        output
            .changeCoverImage
            .drive(onNext: { [weak self] image in
                if let image = image {
                    self?.coverImageView.image = image
                    self?.coverImageView.contentMode = .scaleAspectFill
                } else {
                    self?.coverImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
                    self?.coverImageView.contentMode = .scaleAspectFit
                }
            })
            .disposed(by: disposeBag)

        output
            .statusChanged
            .drive(onNext: { [weak self] fanPassId in
                self?.controlRequiredFanPass(fanPassId)
            })
            .disposed(by: disposeBag)

        output
            .popViewController
            .drive(onNext: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
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
    }
}

extension CreatePostViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        if let chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            dismiss(animated: true) { [weak self] in
                let cropViewController = CropViewController(image: chosenImage)
                cropViewController.delegate = self
                cropViewController.view.tag = picker.view.tag

                if picker.view.tag != 0 {
                    cropViewController.aspectRatioLockEnabled = true
                    cropViewController.aspectRatioPickerButtonHidden = true
                    cropViewController.customAspectRatio = CGSize(width: 960, height: 360)
                }

                self?.present(cropViewController, animated: true, completion: nil)
            }
        }
    }
}

extension CreatePostViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        let imgData = NSData(data: image.jpegData(compressionQuality: 1)!)
        print(imgData.count)
        if imgData.count > (1048576 * 10) {
            Toast.showToast("이미지가 10MB를 초과합니다")
        } else {
            if cropViewController.view.tag == 0 {
                self.chosenContentImage.onNext(image)
            } else {
                self.chosenCoverImage.onNext(image)
            }
        }
        cropViewController.dismiss(animated: true)
    }
}

extension CreatePostViewController: KeyboardManagerDelegate {
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

extension CreatePostViewController {
    private func setupRichTextView(_ textView: TextView) {
        let accessibilityLabel = NSLocalizedString("Rich Content", comment: "Post Rich content")
        self.configureDefaultProperties(for: textView, accessibilityLabel: accessibilityLabel)

        textView.delegate = self
        textView.formattingDelegate = self
        textView.textAttachmentDelegate = self
        textView.accessibilityIdentifier = "richContentView"
        textView.clipsToBounds = false

        if #available(iOS 11, *) {
            textView.smartDashesType = .no
            textView.smartQuotesType = .no
        }
    }

    private func setupHTMLTextView(_ textView: UITextView) {
        let accessibilityLabel = NSLocalizedString("HTML Content", comment: "Post HTML content")
        self.configureDefaultProperties(for: textView, accessibilityLabel: accessibilityLabel)

        textView.isHidden = true
        textView.delegate = self
        textView.accessibilityIdentifier = "HTMLContentView"
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.clipsToBounds = false

        if #available(iOS 10, *) {
            textView.adjustsFontForContentSizeCategory = true
        }

        if #available(iOS 11, *) {
            textView.smartDashesType = .no
            textView.smartQuotesType = .no
        }
    }

    func createToolbar() -> Aztec.FormatBar {
//        let mediaItem = makeToolbarButton(identifier: .media)
        let scrollableItems = scrollableItemsForToolbar

        let toolbar = Aztec.FormatBar()

        toolbar.tintColor = .gray
        toolbar.highlightedTintColor = .blue
        toolbar.selectedTintColor = view.tintColor
        toolbar.disabledTintColor = .lightGray
        toolbar.dividerTintColor = .gray

        toolbar.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 44.0)
        toolbar.autoresizingMask = [ .flexibleHeight ]
        toolbar.formatter = self

//        toolbar.leadingItem = mediaItem
        toolbar.setDefaultItems(scrollableItems)

        toolbar.barItemHandler = { [weak self] item in
            self?.handleAction(for: item)
        }

//        toolbar.leadingItemHandler = { [weak self] item in
//            let picker = UIImagePickerController()
//            picker.delegate = self
//            picker.sourceType = UIImagePickerController.SourceType.photoLibrary
//            picker.view.tag = 0
//            self?.present(picker, animated: true, completion: nil)
//        }

        return toolbar
    }

    func makeToolbarButton(identifier: FormattingIdentifier) -> FormatBarItem {
        let button = FormatBarItem(image: identifier.iconImage, identifier: identifier.rawValue)
        button.accessibilityLabel = identifier.accessibilityLabel
        button.accessibilityIdentifier = identifier.accessibilityIdentifier
        return button
    }

    func exportPreviewImageForVideo(atURL url: URL, onCompletion: @escaping (UIImage) -> (), onError: @escaping () -> ()) {
        DispatchQueue.global(qos: .background).async {
            let asset = AVURLAsset(url: url)
            guard asset.isExportable else {
                onError()
                return
            }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTimeMake(value: 2, timescale: 1))],
                                                     completionHandler: { (time, cgImage, actualTime, result, error) in
                                                        guard let cgImage = cgImage else {
                                                            DispatchQueue.main.async {
                                                                onError()
                                                            }
                                                            return
                                                        }
                                                        let image = UIImage(cgImage: cgImage)
                                                        DispatchQueue.main.async {
                                                            onCompletion(image)
                                                        }
            })
        }
    }

    func downloadImage(from url: URL, success: @escaping (UIImage) -> Void, onFailure failure: @escaping () -> Void) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, _, error) in
            DispatchQueue.main.async {
                guard self != nil else {
                    return
                }

                guard error == nil, let data = data, let image = UIImage(data: data, scale: UIScreen.main.scale) else {
                    failure()
                    return
                }

                self?.fakeUpdateEditorView()

                success(image)
            }
        }

        task.resume()
    }
}


extension CreatePostViewController {

    struct Constants {
        static let defaultContentFont   = UIFont.systemFont(ofSize: 14)
        static let defaultHtmlFont      = UIFont.systemFont(ofSize: 24)
        static let defaultMissingImage  = Gridicon.iconOfType(.image)
        static let formatBarIconSize    = CGSize(width: 20.0, height: 20.0)
        static let lists                = [TextList.Style.unordered, .ordered]
    }

    struct MediaProgressKey {
        static let mediaID = ProgressUserInfoKey("mediaID")
        static let videoURL = ProgressUserInfoKey("videoURL")
    }

    private func configureDefaultProperties(for textView: UITextView, accessibilityLabel: String) {
        textView.accessibilityLabel = accessibilityLabel
        textView.font = Constants.defaultContentFont
        textView.keyboardDismissMode = .interactive
        textView.textColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1)
        textView.linkTextAttributes = [.foregroundColor: UIColor(red: 0x01 / 255.0, green: 0x60 / 255.0, blue: 0x87 / 255.0, alpha: 1), NSAttributedString.Key.underlineStyle: NSNumber(value: NSUnderlineStyle.single.rawValue)]
    }

    func handleAction(for barItem: FormatBarItem) {
        guard let identifier = barItem.identifier,
            let formattingIdentifier = FormattingIdentifier(rawValue: identifier) else {
                return
        }

        switch formattingIdentifier {
        case .bold:
            toggleBold()
        case .italic:
            toggleItalic()
        case .underline:
            toggleUnderline()
        case .link:
            toggleLink()
        case .media:
            toggleImage()
        case .more:
            toggleVideo()
//        case .unorderedlist, .orderedlist:
//            toggleList(fromItem: barItem)
        case .sourcecode:
            toggleEditingMode()
        case .code:
            toggleCode()
        default:
            break
        }

        updateFormatBar()
    }

    @objc func toggleBold() {
        richTextView.toggleBold(range: richTextView.selectedRange)
    }

    @objc func toggleItalic() {
        richTextView.toggleItalic(range: richTextView.selectedRange)
    }

    func toggleUnderline() {
        richTextView.toggleUnderline(range: richTextView.selectedRange)
    }

    @objc func toggleLink() {
        var linkTitle = ""
        var linkURL: URL? = nil
        var linkRange = richTextView.selectedRange
        // Let's check if the current range already has a link assigned to it.
        if let expandedRange = richTextView.linkFullRange(forRange: richTextView.selectedRange) {
            linkRange = expandedRange
            linkURL = richTextView.linkURL(forRange: expandedRange)
        }
        let target = richTextView.linkTarget(forRange: richTextView.selectedRange)
        linkTitle = richTextView.attributedText.attributedSubstring(from: linkRange).string
        let allowTextEdit = !richTextView.attributedText.containsAttachments(in: linkRange)
        showLinkDialog(forURL: linkURL, text: linkTitle, target: target, range: linkRange, allowTextEdit: allowTextEdit)
    }

    @objc func toggleImage() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = UIImagePickerController.SourceType.photoLibrary
        picker.view.tag = 0
        self.present(picker, animated: true, completion: nil)
    }

    @objc func toggleVideo() {
        var linkTitle = ""
        var linkURL: URL? = nil
        var linkRange = richTextView.selectedRange
        // Let's check if the current range already has a link assigned to it.
        if let expandedRange = richTextView.linkFullRange(forRange: richTextView.selectedRange) {
            linkRange = expandedRange
            linkURL = richTextView.linkURL(forRange: expandedRange)
        }
        let target = richTextView.linkTarget(forRange: richTextView.selectedRange)
        linkTitle = richTextView.attributedText.attributedSubstring(from: linkRange).string
        let allowTextEdit = !richTextView.attributedText.containsAttachments(in: linkRange)
        showVideoDialog(forURL: linkURL, text: linkTitle, target: target, range: linkRange, allowTextEdit: allowTextEdit)
    }

    @objc func toggleUnorderedList() {
        richTextView.toggleUnorderedList(range: richTextView.selectedRange)
    }

    @objc func toggleOrderedList() {
        richTextView.toggleOrderedList(range: richTextView.selectedRange)
    }

    @IBAction func toggleEditingMode() {
        formatBar.overflowToolbar(expand: true)
        editorView.toggleEditingMode()
    }

    @objc func toggleCode() {

//        richTextView.toggleCode(range: richTextView.selectedRange)
    }

    func updateFormatBar() {
        guard let toolbar = richTextView.inputAccessoryView as? Aztec.FormatBar else {
            return
        }

        let identifiers: Set<FormattingIdentifier>
        if richTextView.selectedRange.length > 0 {
            identifiers = richTextView.formattingIdentifiersSpanningRange(richTextView.selectedRange)
        } else {
            identifiers = richTextView.formattingIdentifiersForTypingAttributes()
        }

        toolbar.selectItemsMatchingIdentifiers(identifiers.map({ $0.rawValue }))
    }

    func listTypeForSelectedText() -> TextList.Style? {
        var identifiers = Set<FormattingIdentifier>()
        if (richTextView.selectedRange.length > 0) {
            identifiers = richTextView.formattingIdentifiersSpanningRange(richTextView.selectedRange)
        } else {
            identifiers = richTextView.formattingIdentifiersForTypingAttributes()
        }
        let mapping: [FormattingIdentifier: TextList.Style] = [
            .orderedlist : .ordered,
            .unorderedlist : .unordered
        ]
        for (key,value) in mapping {
            if identifiers.contains(key) {
                return value
            }
        }

        return nil
    }

    func showLinkDialog(forURL url: URL?, text: String?, target: String?, range: NSRange, allowTextEdit: Bool = true) {

        let isInsertingNewLink = (url == nil)
        let urlToUse = url

        let alertController = UIAlertController(
            title: "Insert Link",
            message:nil,
            preferredStyle:UIAlertController.Style.alert)
        alertController.view.accessibilityIdentifier = "linkModal"

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextField.ViewMode.always
            textField.placeholder = "Enter link URL"
            textField.keyboardType = .URL
            if #available(iOS 10, *) {
                textField.textContentType = .URL
            }
            textField.text = urlToUse?.absoluteString

            textField.accessibilityIdentifier = "linkModalURL"
        })

        let insertAction = UIAlertAction(
            title: "Insert",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.richTextView.becomeFirstResponder()
                guard let textFields = alertController.textFields else {
                    return
                }
                let linkURLField = textFields[0]
                let linkURLString = linkURLField.text
                var linkTitle = text

                if linkTitle == nil  || linkTitle!.isEmpty {
                    linkTitle = linkURLString
                }

                guard let urlString = linkURLString, let url = URL(string: urlString) else {
                    return
                }

                if let title = linkTitle {
                    self?.richTextView.setLink(url, title: title, target: "\"_blank\"", inRange: range)
                }
            })

        insertAction.accessibilityLabel = "insertLinkButton"

        let removeAction = UIAlertAction(
            title: "Remove Link",
            style:UIAlertAction.Style.destructive,
            handler:{ [weak self] action in
                self?.richTextView.becomeFirstResponder()
                self?.richTextView.removeLink(inRange: range)
            })

        let cancelAction = UIAlertAction(
            title: "Cancel",
            style:UIAlertAction.Style.cancel,
            handler:{ [weak self] action in
                self?.richTextView.becomeFirstResponder()
            })

        if !isInsertingNewLink {
            alertController.addAction(removeAction)
        }
        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    func showVideoDialog(forURL url: URL?, text: String?, target: String?, range: NSRange, allowTextEdit: Bool = true) {

        let isInsertingNewLink = (url == nil)
        let urlToUse = url

        let alertController = UIAlertController(
            title: "Insert Link",
            message:nil,
            preferredStyle:UIAlertController.Style.alert)
        alertController.view.accessibilityIdentifier = "linkModal"

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextField.ViewMode.always
            textField.placeholder = "Enter link URL"
            textField.keyboardType = .URL
            if #available(iOS 10, *) {
                textField.textContentType = .URL
            }
            textField.text = urlToUse?.absoluteString

            textField.accessibilityIdentifier = "linkModalURL"
        })

        let insertAction = UIAlertAction(
            title: "Insert",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.richTextView.becomeFirstResponder()
                guard let textFields = alertController.textFields else {
                    return
                }
                let linkURLField = textFields[0]
                let linkURLString = linkURLField.text
                var linkTitle = text

                if linkTitle == nil  || linkTitle!.isEmpty {
                    linkTitle = linkURLString
                }

                guard let urlString = linkURLString, let url = URL(string: urlString) else {
                    return
                }

                let posterUrlString = urlString.getYoutubePosterUrlString()
                guard let posterUrl = URL(string: posterUrlString) else {
                    return
                }

                if let title = linkTitle {
                    self?.richTextView.replaceWithVideo(at: range, sourceURL: url, posterURL: posterUrl, placeHolderImage: nil)
                }
        })

        insertAction.accessibilityLabel = "insertLinkButton"

        let removeAction = UIAlertAction(
            title: "Remove Link",
            style:UIAlertAction.Style.destructive,
            handler:{ [weak self] action in
                self?.richTextView.becomeFirstResponder()
                self?.richTextView.removeLink(inRange: range)
        })

        let cancelAction = UIAlertAction(
            title: "Cancel",
            style:UIAlertAction.Style.cancel,
            handler:{ [weak self] action in
                self?.richTextView.becomeFirstResponder()
        })

        if !isInsertingNewLink {
            alertController.addAction(removeAction)
        }
        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    func changeRichTextInputView(to: UIView?) {
        if richTextView.inputView == to {
            return
        }

        richTextView.inputView = to
        richTextView.reloadInputViews()
    }

    func saveToDisk(image: UIImage) -> URL {
        let fileName = "\(ProcessInfo.processInfo.globallyUniqueString)_file.jpg"

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            fatalError("Could not conert image to JPEG.")
        }

        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        guard (try? data.write(to: fileURL, options: [.atomic])) != nil else {
            fatalError("Could not write the image to disk.")
        }

        return fileURL
    }

    @objc func timerFireMethod(_ timer: Timer) {
        guard let progress = timer.userInfo as? Progress,
            let imageId = progress.userInfo[MediaProgressKey.mediaID] as? String,
            let attachment = richTextView.attachment(withId: imageId)
            else {
                timer.invalidate()
                return
        }
        progress.completedUnitCount += 1

        attachment.progress = progress.fractionCompleted
        if mediaErrorMode && progress.fractionCompleted >= 0.25 {
            timer.invalidate()
            let message = NSAttributedString(string: "Upload failed!", attributes: mediaMessageAttributes)
            attachment.message = message
            attachment.overlayImage = Gridicon.iconOfType(.refresh)
        }
        if progress.fractionCompleted >= 1 {
            timer.invalidate()
            attachment.progress = nil
            if let videoAttachment = attachment as? VideoAttachment, let videoURL = progress.userInfo[MediaProgressKey.videoURL] as? URL {
                videoAttachment.updateURL(videoURL)
            }
        }
        richTextView.refresh(attachment, overlayUpdateOnly: true)
    }

    var mediaMessageAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                                                         .paragraphStyle: paragraphStyle,
                                                         .foregroundColor: UIColor.white]
        return attributes
    }

    func displayActions(forAttachment attachment: MediaAttachment, position: CGPoint) {
        let mediaID = attachment.identifier
        let title: String = NSLocalizedString("Media Options", comment: "Title for action sheet with media options.")
        let message: String? = nil
        let alertController = UIAlertController(title: title, message:message, preferredStyle: .actionSheet)
        let dismissAction = UIAlertAction(title: NSLocalizedString("Dismiss", comment: "User action to dismiss media options."),
                                          style: .cancel,
                                          handler: { [weak self] (action) in
                                            self?.resetMediaAttachmentOverlay(attachment)
                                            self?.richTextView.refresh(attachment)
            }
        )
        alertController.addAction(dismissAction)

        let removeAction = UIAlertAction(title: NSLocalizedString("Remove Media", comment: "User action to remove media."),
                                         style: .destructive,
                                         handler: { [weak self] (action) in
                                            self?.richTextView.remove(attachmentID: mediaID)
        })
        alertController.addAction(removeAction)

        if let videoAttachment = attachment as? VideoAttachment, let videoURL = videoAttachment.mediaURL {
            let detailsAction = UIAlertAction(title:NSLocalizedString("Play Video", comment: "User action to play video."),
                                              style: .default,
                                              handler: { [weak self] (action) in
                                                self?.displayVideoPlayer(for: videoURL)
            })
            alertController.addAction(detailsAction)
        }

        alertController.title = title
        alertController.message = message
        alertController.popoverPresentationController?.sourceView = richTextView
        alertController.popoverPresentationController?.sourceRect = CGRect(origin: position, size: CGSize(width: 1, height: 1))
        alertController.popoverPresentationController?.permittedArrowDirections = .any
        present(alertController, animated:true, completion: nil)
    }

    func fakeUpdateEditorView() {
        richTextView.toggleBold(range: NSRange(location: 0, length: 1))
        richTextView.toggleBold(range: NSRange(location: 0, length: 1))
    }
}

extension CreatePostViewController: UITextViewDelegate {
    func textViewDidChangeSelection(_ textView: UITextView) {
        updateFormatBar()
        changeRichTextInputView(to: nil)
    }

    func textViewDidChange(_ textView: UITextView) {
        switch textView {
        case richTextView:
            updateFormatBar()
        default:
            break
        }
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        switch textView {
        case richTextView:
            formatBar.enabled = true
        case htmlTextView:
            formatBar.enabled = false

            // Disable the bar, except for the source code button
            let htmlButton = formatBar.items.first(where: { $0.identifier == FormattingIdentifier.sourcecode.rawValue })
            htmlButton?.isEnabled = true
        default: break
        }

        textView.inputAccessoryView = formatBar

        return true
    }
}

extension CreatePostViewController: Aztec.TextViewFormattingDelegate {
    func textViewCommandToggledAStyle() {
        updateFormatBar()
    }
}

extension CreatePostViewController: Aztec.FormatBarDelegate {
    func formatBarTouchesBegan(_ formatBar: FormatBar) {
    }

    func formatBar(_ formatBar: FormatBar, didChangeOverflowState state: FormatBarOverflowState) {
        switch state {
        case .hidden:
            print("Format bar collapsed")
        case .visible:
            print("Format bar expanded")
        }
    }
}

extension CreatePostViewController: TextViewAttachmentDelegate {
    func textView(_ textView: TextView, attachment: NSTextAttachment, imageAt url: URL, onSuccess success: @escaping (UIImage) -> Void, onFailure failure: @escaping () -> Void) {
        switch attachment {
        case let videoAttachment as VideoAttachment:
            guard let posterURL = videoAttachment.posterURL else {
                // Let's get a frame from the video directly
                if let videoURL = videoAttachment.mediaURL {
                    exportPreviewImageForVideo(atURL: videoURL, onCompletion: success, onError: failure)
                } else {
                    exportPreviewImageForVideo(atURL: url, onCompletion: success, onError: failure)
                }
                return
            }
            downloadImage(from: posterURL, success: success, onFailure: failure)
        case let imageAttachment as ImageAttachment:
            if let imageURL = imageAttachment.url {
                downloadImage(from: imageURL, success: success, onFailure: failure)
            } else {
                failure()
            }
        default:
            failure()
        }
    }

    func textView(_ textView: TextView, placeholderFor attachment: NSTextAttachment) -> UIImage {
        print("placeholder")
        return placeholderImage(for: attachment)
    }

    func placeholderImage(for attachment: NSTextAttachment) -> UIImage {
        let imageSize = CGSize(width: 64, height: 64)

        let placeholderImage: UIImage
        switch attachment {
        case _ as ImageAttachment:
            placeholderImage = Gridicon.iconOfType(.image, withSize: imageSize)
        case _ as VideoAttachment:
            placeholderImage = Gridicon.iconOfType(.video, withSize: imageSize)
        default:
            placeholderImage = Gridicon.iconOfType(.attachment, withSize: imageSize)
        }

        return placeholderImage
    }

    func textView(_ textView: TextView, urlFor imageAttachment: ImageAttachment) -> URL? {
        guard let image = imageAttachment.image else {
            return nil
        }

        // TODO: start fake upload process
        print("imageAttachment")

        return saveToDisk(image: image)
    }

    func textView(_ textView: TextView, deletedAttachment attachment: MediaAttachment) {
        print("Attachment \(attachment.identifier) removed.\n")
    }

    func textView(_ textView: TextView, selected attachment: NSTextAttachment, atPosition position: CGPoint) {
        switch attachment {
        case _ as ImageAttachment:
            break
        case let attachment as MediaAttachment:
            selected(textAttachment: attachment, atPosition: position)
        default:
            break
        }
    }

    func textView(_ textView: TextView, deselected attachment: NSTextAttachment, atPosition position: CGPoint) {
        deselected(textAttachment: attachment, atPosition: position)
    }

    fileprivate func resetMediaAttachmentOverlay(_ mediaAttachment: MediaAttachment) {
        mediaAttachment.overlayImage = nil
        mediaAttachment.message = nil
    }

    func selected(textAttachment attachment: MediaAttachment, atPosition position: CGPoint) {

        if (currentSelectedAttachment == attachment) {
            displayActions(forAttachment: attachment, position: position)
        } else {
            if let selectedAttachment = currentSelectedAttachment {
                resetMediaAttachmentOverlay(selectedAttachment)
                richTextView.refresh(selectedAttachment)
            }

            // and mark the newly tapped attachment
            if attachment.message == nil {
                let message = NSLocalizedString("Options", comment: "Options to show when tapping on a media object on the post/page editor.")
                attachment.message = NSAttributedString(string: message, attributes: mediaMessageAttributes)
            }
            attachment.overlayImage = Gridicon.iconOfType(.pencil, withSize: CGSize(width: 32.0, height: 32.0)).withRenderingMode(.alwaysTemplate)
            richTextView.refresh(attachment)
            currentSelectedAttachment = attachment
        }
    }

    func deselected(textAttachment attachment: NSTextAttachment, atPosition position: CGPoint) {
        currentSelectedAttachment = nil
        if let mediaAttachment = attachment as? MediaAttachment {
            resetMediaAttachmentOverlay(mediaAttachment)
            richTextView.refresh(mediaAttachment)
        }
    }

    func displayVideoPlayer(for videoURL: URL) {
        let safariViewController = SFSafariViewController(url: videoURL)
        present(safariViewController, animated: true, completion: nil)
//        let asset = AVURLAsset(url: videoURL)
//        let controller = AVPlayerViewController()
//        let playerItem = AVPlayerItem(asset: asset)
//        let player = AVPlayer(playerItem: playerItem)
//        controller.showsPlaybackControls = true
//        controller.player = player
//        player.play()
//        present(controller, animated:true, completion: nil)
    }
}

extension FormattingIdentifier {

    var iconImage: UIImage {

        switch(self) {
        case .media:
            return gridicon(.image)
        case .p:
            return gridicon(.heading)
        case .bold:
            return gridicon(.bold)
        case .italic:
            return gridicon(.italic)
        case .underline:
            return gridicon(.underline)
        case .strikethrough:
            return gridicon(.strikethrough)
        case .blockquote:
            return gridicon(.quote)
        case .orderedlist:
            return gridicon(.listOrdered)
        case .unorderedlist:
            return gridicon(.listUnordered)
        case .link:
            return gridicon(.link)
        case .horizontalruler:
            return gridicon(.minusSmall)
        case .sourcecode:
            return gridicon(.code)
        case .more:
            return gridicon(.video)
        case .header1:
            return gridicon(.headingH1)
        case .header2:
            return gridicon(.headingH2)
        case .header3:
            return gridicon(.headingH3)
        case .header4:
            return gridicon(.headingH4)
        case .header5:
            return gridicon(.headingH5)
        case .header6:
            return gridicon(.headingH6)
        case .code:
            return gridicon(.posts)
        default:
            return gridicon(.help)
        }
    }

    private func gridicon(_ gridiconType: GridiconType) -> UIImage {
        let size = CreatePostViewController.Constants.formatBarIconSize
        return Gridicon.iconOfType(gridiconType, withSize: size)
    }

    var accessibilityIdentifier: String {
        switch(self) {
        case .media:
            return "formatToolbarInsertMedia"
        case .p:
            return "formatToolbarSelectParagraphStyle"
        case .bold:
            return "formatToolbarToggleBold"
        case .italic:
            return "formatToolbarToggleItalic"
        case .underline:
            return "formatToolbarToggleUnderline"
        case .strikethrough:
            return "formatToolbarToggleStrikethrough"
        case .blockquote:
            return "formatToolbarToggleBlockquote"
        case .orderedlist:
            return "formatToolbarToggleListOrdered"
        case .unorderedlist:
            return "formatToolbarToggleListUnordered"
        case .link:
            return "formatToolbarInsertLink"
        case .horizontalruler:
            return "formatToolbarInsertHorizontalRuler"
        case .sourcecode:
            return "formatToolbarToggleHtmlView"
        case .more:
            return "formatToolbarInsertMore"
        case .header1:
            return "formatToolbarToggleH1"
        case .header2:
            return "formatToolbarToggleH2"
        case .header3:
            return "formatToolbarToggleH3"
        case .header4:
            return "formatToolbarToggleH4"
        case .header5:
            return "formatToolbarToggleH5"
        case .header6:
            return "formatToolbarToggleH6"
        case .code:
            return "formatToolbarCode"
        default:
            return ""
        }
    }

    var accessibilityLabel: String {
        switch(self) {
        case .media:
            return NSLocalizedString("Insert media", comment: "Accessibility label for insert media button on formatting toolbar.")
        case .p:
            return NSLocalizedString("Select paragraph style", comment: "Accessibility label for selecting paragraph style button on formatting toolbar.")
        case .bold:
            return NSLocalizedString("Bold", comment: "Accessibility label for bold button on formatting toolbar.")
        case .italic:
            return NSLocalizedString("Italic", comment: "Accessibility label for italic button on formatting toolbar.")
        case .underline:
            return NSLocalizedString("Underline", comment: "Accessibility label for underline button on formatting toolbar.")
        case .strikethrough:
            return NSLocalizedString("Strike Through", comment: "Accessibility label for strikethrough button on formatting toolbar.")
        case .blockquote:
            return NSLocalizedString("Block Quote", comment: "Accessibility label for block quote button on formatting toolbar.")
        case .orderedlist:
            return NSLocalizedString("Ordered List", comment: "Accessibility label for Ordered list button on formatting toolbar.")
        case .unorderedlist:
            return NSLocalizedString("Unordered List", comment: "Accessibility label for unordered list button on formatting toolbar.")
        case .link:
            return NSLocalizedString("Insert Link", comment: "Accessibility label for insert link button on formatting toolbar.")
        case .horizontalruler:
            return NSLocalizedString("Insert Horizontal Ruler", comment: "Accessibility label for insert horizontal ruler button on formatting toolbar.")
        case .sourcecode:
            return NSLocalizedString("HTML", comment:"Accessibility label for HTML button on formatting toolbar.")
        case .more:
            return NSLocalizedString("More", comment:"Accessibility label for the More button on formatting toolbar.")
        case .header1:
            return NSLocalizedString("Heading 1", comment: "Accessibility label for selecting h1 paragraph style button on the formatting toolbar.")
        case .header2:
            return NSLocalizedString("Heading 2", comment: "Accessibility label for selecting h2 paragraph style button on the formatting toolbar.")
        case .header3:
            return NSLocalizedString("Heading 3", comment: "Accessibility label for selecting h3 paragraph style button on the formatting toolbar.")
        case .header4:
            return NSLocalizedString("Heading 4", comment: "Accessibility label for selecting h4 paragraph style button on the formatting toolbar.")
        case .header5:
            return NSLocalizedString("Heading 5", comment: "Accessibility label for selecting h5 paragraph style button on the formatting toolbar.")
        case .header6:
            return NSLocalizedString("Heading 6", comment: "Accessibility label for selecting h6 paragraph style button on the formatting toolbar.")
        case .code:
            return NSLocalizedString("Code", comment: "Accessibility label for selecting code style button on the formatting toolbar.")
        default:
            return ""
        }

    }
}

private extension TextList.Style {
    var formattingIdentifier: FormattingIdentifier {
        switch self {
        case .ordered:   return FormattingIdentifier.orderedlist
        case .unordered: return FormattingIdentifier.unorderedlist
        }
    }

    var description: String {
        switch self {
        case .ordered: return "Ordered List"
        case .unordered: return "Unordered List"
        }
    }

    var iconImage: UIImage? {
        return formattingIdentifier.iconImage
    }
}
